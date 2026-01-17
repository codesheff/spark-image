# My Notes


## To rebuild and publish images
`
to be added
./build-all-images.sh   # ( this calls ./build-image.sh)
`

## deploy to kubernetes ( and also to recreate the Kustomize patch files)
`
./scripts/redeploy.sh 3.5.7 --deploy 
`

# to test 
`
./scripts/test-livy.sh 
`
nb you may have to port foward first to allow us to connect to livy url


# To Do
[ ] - understand how to get it to create driver and executor pods
     ( is this just issue with my test kubernetes env?)
[ ] - identify and delete unnecessary scripts
[ ] - reduce and simplify documentation
[ ] - continue working through project-plan.md
