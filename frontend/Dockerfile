# Step1 Get the base Image
FROM nginx:alpine

# Step2 Set the Working Directory
COPY . /usr/share/nginx/html

# Step3 Expose
EXPOSE 80

# Step4 CMD
CMD ["nginx", "-g", "daemon off;"]