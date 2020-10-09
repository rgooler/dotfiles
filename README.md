My Dotfiles
===========

These are my dotfiles, managed by [Dotbot][dotbot].

To install, simply run the install script. It does the rest. And be sure to clone this repo with `--recursive` in order to grab the submodules that make it work.

This also has a nice zsh theme that requires the powerline 'Hack' font. It can be found here: https://powerline.readthedocs.io/en/latest/installation.html#installation-on-various-platforms

Notes
-----

To keep submodules at their proper versions, you could include something like
`git submodule update --init --recursive` in your `install.conf.yaml`.

To upgrade your submodules to their latest versions, you could periodically run
`git submodule update --init --remote`.

License
-------

This software is hereby released into the public domain. That means you can do
whatever you want with it without restriction. See `LICENSE.md` for details.
