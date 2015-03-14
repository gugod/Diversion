use inc::Module::Install;
name 'Diversion';
version '0.1';
author 'Kang-min Liu <gugod@guogd.org>';

install_script "bin/feed-archiver.pl";
install_script "bin/feed-archive-email.pl";

license 'cc0';

cpanfile;
WriteAll;
