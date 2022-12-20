# Introduction
This repository imitates [packages.debian.org](https://www.debian.org/distrib/packages) for Jessie (Debian 8) PowerPC.
It lets you search for powerpc architecture packages from the jessie release of Debian.

## Why?
Jessie is the [last Debian release](https://www.debian.org/ports/powerpc/#powerpc) to officially support the 32-bit PowerPC architecture.  It's still being run on old PowerMacs, CHRP systems, some Amigas, and other embedded devices using a PowerPC SOC, like the [Western Digital My Book Live](https://github.com/ewaldc/My-Book-Live).

But there's no easy way to search for packages in Jessie anymore -- it's no longer available on packages.debian.org; and the PowerPC architecture has also been removed from search completely.

This repository allows you to spin up your own imitation packages site, just to search for Jessie PowerPC packages, and explore their dependencies.

# How to use this image
This image contains a pre-populated index of PowerPC packages from:
 - jessie in [archive.debian.org](http://archive.debian.org/)
 - jessie-backports in [archive.debian.org](http://archive.debian.org/)
 - sid (unstable) & experimental in [ports.debian.org](https://www.ports.debian.org/)

Run it with:
`docker run -p 80:80 ghcr.io/peterdey/jessie-powerpc-packages:latest`

Alternatively, to run it without docker, follow the instructions in INSTALL.

## Updating the packages
Packages in jessie and jessie-backports are unlikely to change.
Sid & experimental however may fall out of date.

Update the package index with:
`docker exec <container_name> bin/daily`