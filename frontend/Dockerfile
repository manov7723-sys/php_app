# Step1 Get the base Image
FROM nginx:alpine

# Step2 Set the Working Directory
WORKDIR /usr/share/nginx/html

# Step3 Copy Entire application code
COPY . .

# Step4 Expose
EXPOSE 80

# Step5 CMD
CMD ["ginx", "-g", "daemon off;"]