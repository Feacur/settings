find commits with a file
```
git log --all -- %path%
```

wipe all untracked files away
```
git clean -fdx --exclude=%path%
```

reset even a rebased branch
```
git reset --hard %branch%
```

enforce a new branch head
```
git branch --force %branch% %commit%
```

download even a large repo
```
git clone --depth 1 %source% --branch master
git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
git remote set-branches origin '*'
git fetch --deepen %depth%
git fetch --unshallow
```