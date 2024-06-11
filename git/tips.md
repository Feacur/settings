git workflow
```
# open `.gitconfig` in the editor
> git config --global --edit
```

repository workflow
```
# wipe all untracked files away
> git clean -fdx --exclude=%path%

# download a large repo
> git clone --depth 1 %source% --branch master
> git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
> git remote set-branches origin '*'
> git fetch --deepen %depth%
> git fetch --unshallow

# fix line endings
git add . --renormalize
```

remotes workflow
```
# switch
> git remote set-url %remote% %url%

# add a new one; as a convention
# - "origin" denotes a forked repo
# - "upstream" points to the original
> git remote add %remote% %url%

# create branch
> git push --set-upstream
> [or] git push %remote% %branch%
>      git branch --set-upstream-to=%remote%/%branch%

# delete branch
> git push --delete %remote% %branch%
```

branches workflow
```
# create local
> git branch %branch%

# delete local
> git branch --delete %branch%

# switch
> git checkout %branch%
> [or] git switch %branch%

# reset file to another branch's version
> git checkout %branch% -- %path%

# create and switch
> git checkout --branch %branch%
> [or] git switch --create %branch%

# enforce a new branch head
> git branch --force %branch% %commit%

# reset even a rebased branch
> git reset --hard %branch%

# find branch with a commit
> git branch --all --contains %commit%
> [or] git reflog show --all | rg %commit%
  # grep, ripgrep, anything
```

commits workflow
```
# find commits with a file
> git log --all -- %path%
```
