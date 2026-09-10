locals {
  cluster_name = "the-new-dev"
  region       = "us-east-1"

  tags = {
    ManagedBy   = "DeepAgent"
    Cluster     = local.cluster_name
    Environment = "production"
    Team        = "devops"
  }
}

# Reusing existing VPC vpc-06993a44b844fa501 with the given subnets.
locals {
  vpc_id         = "vpc-06993a44b844fa501"
  subnet_ids     = ["subnet-041461c378eb782d3", "subnet-0ad23726193427155", "subnet-0a1b1d82822bcc5fd", "subnet-086dbc8be4e873552", "subnet-074983bd6d2e33ae5", "subnet-086802edb9b056b33"]
  node_subnet_ids = ["subnet-041461c378eb782d3", "subnet-086dbc8be4e873552", "subnet-086802edb9b056b33"]
}

# ────────────────────────────────────────────────────────────────────────
# Tag the reused VPC's subnets so Kubernetes can place load balancers.
# Public/private is detected from each subnet's map_public_ip_on_launch —
# never assumed. Uses aws_ec2_tag (single-tag management) so existing tags
# on these subnets are left untouched.
# ────────────────────────────────────────────────────────────────────────
locals {
  # Union of control-plane + node subnets; both need the cluster tag.
  all_subnet_ids = toset(concat(local.subnet_ids, local.node_subnet_ids))
}

data "aws_subnet" "tagged" {
  for_each = local.all_subnet_ids
  id       = each.value
}

resource "aws_ec2_tag" "subnet_elb_role" {
  for_each = {
    for id, s in data.aws_subnet.tagged : id => s if s.map_public_ip_on_launch
  }
  resource_id = each.key
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

resource "aws_ec2_tag" "subnet_internal_elb_role" {
  for_each = {
    for id, s in data.aws_subnet.tagged : id => s if !s.map_public_ip_on_launch
  }
  resource_id = each.key
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

resource "aws_ec2_tag" "subnet_cluster_shared" {
  for_each    = local.all_subnet_ids
  resource_id = each.value
  key         = "kubernetes.io/cluster/${local.cluster_name}"
  value       = "shared"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = "1.36"

  # Required for the AWS Load Balancer Controller (and EBS CSI IRSA) to bind
  # IAM roles to Kubernetes service accounts via the cluster's OIDC issuer.
  enable_irsa = true

  # STANDARD support, explicitly. A cluster left on EXTENDED support keeps
  # running past its Kubernetes version's standard-support window — and AWS
  # charges roughly 6x the control-plane rate for the privilege (~$0.60/hr vs
  # ~$0.10/hr). That is a silent ~$365/month per cluster for a setting nobody
  # chose. STANDARD means the cluster must be upgraded before end-of-support,
  # which is the behaviour you want by default; opt into EXTENDED deliberately.
  cluster_upgrade_policy = {
    support_type = "STANDARD"
  }

  # API-only auth. Access is granted purely through EKS Access Entries (see
  # access_entries below), not the legacy aws-auth ConfigMap. Keeping the
  # ConfigMap path alive means two sources of truth for cluster access, and
  # editing it by hand is the classic way to lock everyone out of a cluster.
  authentication_mode = "API"

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

  # Control-plane logging → CloudWatch (api, audit, authenticator, controllerManager, scheduler).
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # No secrets-at-rest encryption: the module would otherwise mint a KMS key
  # per apply, and a state-loss retry then plans a full cluster REPLACEMENT
  # (key mismatch is a ForceNew attribute) that 409s on its own name.
  create_kms_key            = false
  cluster_encryption_config = {}

  cluster_addons = {
    coredns    = { most_recent = true }
    kube-proxy = { most_recent = true }
    # PREFIX DELEGATION — the difference between "this cluster works" and a
    # deploy that hangs forever with no error anyone can find.
    #
    # WHAT BREAKS WITHOUT IT (2026-09, deepagentdevops-dev). The VPC CNI's
    # default is one secondary IP per pod, and an instance's IP budget is tiny:
    # an m5.large gets 3 ENIs x 10 IPs, so ~27 pods before the node runs dry.
    # Past that, pods SCHEDULE FINE — the scheduler only weighs CPU and memory,
    # and the node has plenty of both — and then sit in ContainerCreating with
    #
    #     failed to setup network for sandbox ... aws-cni failed (add):
    #     add cmd: failed to assign an IP address to container
    #
    # forever. Seven pods across four projects sat like that for 44 hours.
    #
    # The Cluster Autoscaler cannot rescue it either: it scales on PENDING
    # pods, and these are not pending — they are assigned to a node that
    # cannot give them an address. The one signal that would have added a node
    # is invisible to the one component that adds nodes.
    #
    # Prefix delegation hands each ENI a /28 (16 addresses) instead of single
    # IPs, so the same instance supports hundreds. It must be set AT CLUSTER
    # CREATION: the CNI only takes prefixes on ENIs attached after the setting
    # is live, so flipping it on a running cluster leaves every existing node
    # exactly as stuck as before — which is what made this so hard to unstick.
    #
    # WARM_PREFIX_TARGET=1 keeps one spare prefix warm per node: enough that a
    # burst of pods starts immediately, without reserving addresses a small
    # cluster will never use.
    vpc-cni = {
      most_recent = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }

    # metrics-server — without it `kubectl top` returns "Metrics API not
    # available" and every HorizontalPodAutoscaler sits at <unknown>/80% and
    # never scales. Not installed by default by EKS, and its absence is only
    # discovered the first time someone tries to autoscale.
    metrics-server = { most_recent = true }

    # eks-pod-identity-agent — the modern successor to IRSA for granting pods
    # AWS permissions. Harmless when unused; required the moment anyone adds a
    # Pod Identity association, and the console warns about its absence.
    eks-pod-identity-agent = { most_recent = true }
    # EBS CSI driver — MUST have an IRSA-bound service account role,
    # otherwise the controller pods can't call EC2 APIs (CreateVolume,
    # CreateSnapshot, etc.) and the addon hangs at "CREATING" until
    # timeout. See module.ebs_csi_irsa below.
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
    }
  }

  vpc_id     = local.vpc_id
  subnet_ids = local.subnet_ids

  enable_cluster_creator_admin_permissions = true

  access_entries = {
    entry0 = {
      principal_arn = "arn:aws:iam::167313940749:root"
      policy_associations = {
        main = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  eks_managed_node_groups = {
    the-new-dev-workers = {
      subnet_ids     = local.node_subnet_ids
      instance_types = ["m5.large"]
      capacity_type  = "ON_DEMAND"
      ami_type       = "AL2023_x86_64_STANDARD"
      min_size       = 2
      max_size       = 10
      desired_size   = 2
      disk_size      = 100
      labels = { role = "workers" }
    }
  }

  tags = local.tags
}

# ────────────────────────────────────────────────────────────────────────
# EBS CSI driver IRSA role — required for the aws-ebs-csi-driver addon
# to function. Without a role bound to the ebs-csi-controller-sa service
# account, the addon deploys but hangs at CREATING (controller pods can't
# call EC2). The community iam-role-for-service-accounts-eks module
# packages the exact IAM policy + trust the CSI driver needs.
# ────────────────────────────────────────────────────────────────────────
module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name             = "${local.cluster_name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = local.tags
}

# ════════════════════════════════════════════════════════════════════════
# AWS Load Balancer Controller — Terraform-MANAGED, not a manual step.
# ════════════════════════════════════════════════════════════════════════
# WHAT IT DOES: reconciles Kubernetes Ingress objects into ALBs (Layer 7)
# and annotated Services into NLBs (Layer 4).
#
# WHY IT IS DECLARED HERE (2026-07 incident):
#   * It was previously installed by hand via `eksctl create iamserviceaccount`
#     + `helm install`. That does NOT survive a cluster rebuild, cannot be
#     reproduced by a teammate, and drifts silently. Any cluster this module
#     builds now gets the controller in the same `terraform apply`.
#   * Our standard exposure pattern is Service type=ClusterIP + Ingress
#     (ingressClassName=alb) — see the ADR in lib/devops/deploy-manifest.ts.
#     Without this controller, those Ingress objects have nothing to
#     reconcile them and no ALB is ever created.
#   * Private-subnet clusters have NO working alternative: the in-tree
#     cloud-controller-manager only makes Classic ELBs, which cannot attach
#     to private subnets. The Service just hangs at EXTERNAL-IP <pending>
#     with no surfaced error.
#
# Subnet discovery is tag-driven (public: kubernetes.io/role/elb=1, private:
# kubernetes.io/role/internal-elb=1). Both the new-VPC and reuse-existing-VPC
# paths in this file apply those tags.
# ────────────────────────────────────────────────────────────────────────
module "lb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.cluster_name}-alb-controller"

  # NOTE: `attach_load_balancer_controller_policy = true` is deliberately NOT
  # used. That flag attaches a policy SNAPSHOT vendored inside the IAM module,
  # which goes stale as the controller adds permissions in new releases. It is
  # precisely how we shipped a controller role missing
  # elasticloadbalancing:DescribeListenerAttributes, so ALB provisioning failed
  # with 403 AccessDenied *after* we had already switched to Ingress/ALB.
  # We attach the upstream policy instead — see aws_iam_policy.alb_controller.

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = local.tags
}

