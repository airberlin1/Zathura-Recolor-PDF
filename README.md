# Zathura-Recolor-PDF
A bash script that reloads all zathura windows with a new config file, for the purpose of changing the pdf colors

# Usage
This script takes 1 argument: The relative path to the directory containing the zathurarc file to applied, relative to the standard ~/.config/zathura/

The script restarts all zathura files (or on current tag, see dwm), and when they were started with the -c option, it overwrites it to the one specified. In supported Window Managers, it tries to sort zathura back into the previous location.

### Supported Window Managers
- [dwm](https://dwm.suckless.org/)

When starting zathura, use full paths as relative paths will most likely break when using this script.

## With DWM
This script will only affect windows on the current tag.

It is recommended to use the [focusonnetactive](https://dwm.suckless.org/patches/focusonnetactive/) patch. If you do not want to use it, correctly placing the window back will not work automatically and the program could wait indefinitely until the correct windows are manually focused.

Set the option `DWM=1`.

### Known Issues
When used with dwm, the windows that are on top of a zathura window might get put in a different order with this script

## With Hyprland
In development

## With Emacs
Cycling through emacs themes should automatically apply colors to opened pdf files for more colorful study. If you want to use it in a similar way, here are some suggestions:
Call a wrapper script that does not automatically applies an argument to this script and call it with
``` emacs-lisp
(call-process "your-wrapper.sh" nil 0 nil)
```
This prevents immediate termination, but to my knowledge it is not easy to add arguments here.

## With AucTeX
To enable reasonable support in auctex, set the following:

``` emacs-lisp
  (add-to-list 'TeX-expand-list
               '("%Z" (lambda () my:zathura-config-option)))
  (add-to-list 'TeX-expand-list
               '("%O" (lambda ()
                        (expand-file-name
                         (concat (TeX-active-master) ".pdf")))))
  (add-to-list 'TeX-view-program-list '("Zathura" ("zathura -c /home/air_berlin/.config/zathura/%Z %O"
                                                   (mode-io-correlate " --synctex-forward %n:0:%a -x emacsclient\\ +%{line}\\ %{input} ")))))
```

and then set my:zathura-config-option to the argument you would pass to this script.
This let's the view command automatically open zathura in a way that it can be reasonably affected by this script.

## Known Issues
This script quotes all arguments after -x into one. This makes sense for my use case, but it might not be wanted. This is mostly a workaround to quotes from original program calls being lost because `|` is being used for formatting.
