# LAMP stack Automated install

The project will install entire LAMP stack onto a debian based or RHEL based linux system


### Prerequisites

No Prerequisites are needed though the machine where we  install the LAMP stack should have atleast 2GB ram. As we are building all the modules 

### Installing

To install the lamp stack following steps needs to be done 

```
git clone https://github.com/kiritdevda/Haptik-Test.git
cd Question2/lamp
chmod +x -R ./*
```
Before running the script you can tweak parameters for installation in

```
include/config.sh  file
```

Now we can begin with installation. To start installation run lamp.sh script

```
./lamp.sh
```

The Script will ask for parameters like mysql password , wordpress db user password . You can specify it or just hit enter it will take default parameter

## Authors

Kirit Devda - devda_kirit@yahoo.com
Github Profile - https://github.com/kiritdevda
LinkedIn Profile - https://www.linkedin.com/in/kirit-devda-16120384

## Acknowledgments

* https://github.com/teddysun/lamp

## Activites Performed

* Refractor code to remove percona and maria db code
* made code lean by removing rollback and upgrade part 
* Removed command line options to install LAMP stack to make installation light weight and easy to run
* Added wordpress installation module
