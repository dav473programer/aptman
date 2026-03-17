# aptman  
A Debian Package manager written fully in bash.  
Or, a wrapper for apt.  
  
How to install:  
1.Open the terminal  
2.Type "wget -qO- https://raw.githubusercontent.com/dav473programer/aptman/refs/heads/main/config.sh | bash" (without the quotes)  
3.Follow the steps there.  
4.Installed.  
  
How to run it:  
1.Look in the app drawer, or menu (however you call it) and select it there.  
2.Type "aptman" in the terminal  
3.To install a local script "aptman /path/to/script"  
  
What can it do:  
Search packages and install them.  
Search local packages and uninstall them (one or multiple)  
Add repositories from within the app.  
Remove unused or errored out repositories. (only from sources.list.d)  
Update to the latest changes on all your repositories.  
Full upgrade the whole system. (this means replacing everything thats new, even the kernel so be carefull with this.)  
And it can install local .deb packages.  
  
My motivation for making this:  
GDebi didnt want to install my .deb packages, but this does hapily.  
