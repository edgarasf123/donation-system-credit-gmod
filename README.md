## ⚠️Warning⚠️

This is one of my old code, and some parts most likely outdated. I have no interest or time to actually go over the code. If someone wants to use this, feel free to fix it.

# donation-system-credit-gmod

This is heavily upgraded version of my first [Automated Donation System](https://github.com/edgarasf123/donation-system-gmod), which has been sold for over a year. 

This version includes credit system where users can buy credits and then spend those credits on any packages. 

----
## Current Features:
* Pointshop 2 support
* Works on most gamemodes such as DarkRP, TTT, PropHunt, and etc.
* OpenID Steam Authentication (eliminates user error)
* Admin Panel, shows all important data regarding the system.
* gForum(smf) group support.
* Timed ranks for any admin mod that exist, no external addons are required such as &quot;ulx timedranks&quot;.
* Global packages, one purchase will give user perks on multiple servers.
* Predefined donation commands such as giving pointshop points or darkrp money.
* Most configuration is done in one config file, no need to go trough different hosts or files to configure the system.
* User friendly setup.
* Donations through PayPal Donation page.
* Full proof system, perks are guaranteed to be given on the servers, even if the server is down when purchase was completed.
* Multiple vulnerability checks to prevent exploiting. Conforms to current Web Security standards.

## Feature ideas
* SourceMod plugin to support other source games like CSS, TF2, CS:GO, and etc.**
* Direct purchase.
* Dynamic pricing for packages.
* Package restrictions to specific users/groups.
* Bukkit plugin.
* Other payment methods.

** Although SourceMod plugin for my first donation system exists, it&#039;s not compatible with the new system.

----
## Requirements: 
* Verified Paypal account. 
* Web Server with PHP 5.3(or greater) installed. Sites like [enjin.com](http://enjin.com/) won&#039;t work because they don&#039;t support PHP.
* MySQL Server with remote connection enabled, usually comes with the web host. Please note that most free webhosts such as x10hosting or 000webhost doesn&#039;t allow remote connection to the database.
* [MySQLOO v8](http://facepunch.com/showthread.php?t=1220537) installed on your game server. Some game hosting companies doesn&#039;t allow uploading binary files into their servers. You should contact your game host to make sure you are allowed to upload binary files before purchasing this script.
* Basic knowledge on how to use ftp to upload files, and create databases using cpanel. Unless someone else does setup for you.

