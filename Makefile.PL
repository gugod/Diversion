use inc::Module::Install;
name 'Diversion';
version '0.1';
author 'Kang-min Liu <gugod@guogd.org>';

install_script "bin/diversion";
install_share  "share";

license 'cc0';

cpanfile;

WriteAll;
