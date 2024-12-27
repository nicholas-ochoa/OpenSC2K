 # Navigate to the project directory
cd /path/to/your/repository

# Remove the existing Git history
rm -rf .git

# Reinitialize the Git repository
git init

# Add all files to the new repository
git add .

# Commit the current state of the project
git commit -m "Initial commit with current state"
# Add the remote repository URL
git remote add origin <remote-repository-URL>

# Push to the remote repository (force overwriting history)
git push --force origin main
