# Running Via Claude
docker build -t project-planner .
docker run -p 5000:5000 -v planner-data:/data project-planner