# zsh-aggregator

**[SN@ilWare](https://nemo.lpc-caen.in2p3.fr) aggregators for
  [Zsh](http://www.zsh.org).**

How to install
--------------

### In your ~/.zshrc

* Download the script or clone this repository:

``` bash
$ git clone git://github.com/xgarrido/zsh-aggregator.git
```

* Add the cloned directory to `fpath` variable to make use of zsh completion:

``` bash
fpath=(/path/to/zsh-aggregator $fpath)
```

* Source the script **at the end** of `~/.zshrc`:

``` bash
source /path/to/zsh-aggregator/zsh-aggregator.plugin.zsh
```

* Source `~/.zshrc` to take changes into account:

``` bash
$ source ~/.zshrc
```

### With oh-my-zsh

* Download the script or clone this repository in [oh-my-zsh](http://github.com/robbyrussell/oh-my-zsh) plugins directory:

``` bash
$ cd ~/.oh-my-zsh/custom/plugins
$ git clone git://github.com/xgarrido/zsh-aggregator.git
```

* Activate the plugin in `~/.zshrc` (in **last** position):

``` bash
plugins=( [plugins...] zsh-aggregator)
```

* Source `~/.zshrc`  to take changes into account:

``` bash
$ source ~/.zshrc
```

### With [antigen](https://github.com/zsh-users/antigen)

* Add this line to your `~/.zshrc` file:

``` bash
antigen-bundle xgarrido/zsh-aggregator
```

How to use (to be done)
-----------------------

Type `aggregator` and press `TAB` key. You will be prompt to
something like this

```bash
➜  aggregator
build         -- Build a component
configure     -- Configure a component
goto          -- Goto a component directory
rebuild       -- Rebuild component from scratch
reset         -- Reset component
setup         -- Source a component
status        -- Status of a component
svn-checkout  -- SVN checkout a component
svn-diff      -- SVN diff a component
svn-status    -- SVN status of a component
svn-update    -- SVN update a component
test          -- Run tests on a component
```

Pressing again `TAB` key will bring you to the different
options. Let's try `build` option and again try to complete by using `TAB`

```bash
➜  aggregator build
all bayeux cadfael channel chevreuse falaise
```

You can select and build software agregators or build `all` the aggregators in
one time. You can either select the aggregator by using `TAB` key or start to
write the beginning of the name of the aggregator you want to build and use zsh
completion power.
