#!/usr/bin/env python
# Downloads and compiles from source some generally useful software, Culminates in compiling a gtk+ enabled vim.
import os, re, sys, urllib2

HOME = os.environ['HOME']
assert HOME.startswith('/home/')
LOCAL = os.path.join(HOME, '.local')
BUILD_DIR = os.path.join(LOCAL, 'build')  # for tarball archives and builds
INSTALLED_TARBALLS_FILE = os.path.join(LOCAL, 'installed-tarballs')

os.environ['PATH'] = LOCAL + '/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
os.environ['PKG_CONFIG_PATH'] = '%s/lib/pkgconfig:%s/share/pkgconfig' % (LOCAL, LOCAL)
os.environ['CPATH'] = LOCAL + '/include'
os.environ['LIBRARY_PATH'] = LOCAL + '/lib'
os.environ['LD_LIBRARY_PATH'] = LOCAL + '/lib'


def sh(cmd):
    print cmd
    n = os.system(cmd)
    if n != 0:
        raise Exception('Command "%s" terminated with exit code %d' % (cmd, n))

def download(url, path):
    if os.system('which wget >/dev/null') == 0:
        sh("wget -O '%s' '%s'" % (path + '.temp', url))
    elif os.system('which curl >/dev/null') == 0:
        sh("curl '%s' > '%s'" % (url, path + '.temp'))
    else:
        file(path + '.temp', 'w').write(urllib2.urlopen(url).read())
    sh("mv -f '%s' '%s'" % (path + '.temp', path))

def is_installed(package_id):
    if os.path.exists(INSTALLED_TARBALLS_FILE):
        for line in file(INSTALLED_TARBALLS_FILE):
            if line.strip() == package_id:
                return True
    return False

def mark_installed(package_id):
    file(INSTALLED_TARBALLS_FILE, 'a').write(package_id + '\n')

def install_tarball(entry):
    url = entry['url']

    print 'Installing %s' % url

    if not os.path.exists(LOCAL):
        os.makedirs(LOCAL)

    if not os.path.exists(BUILD_DIR):
        os.makedirs(BUILD_DIR)

    if 'url_basename' in entry:
        url_basename = entry['url_basename']
        url_filename = entry['url_filename']
    else:
        m = re.match(r'.*/(([^/]*)\.tar\.(gz|bz2))$', url)
        if not m:
            raise Exception("Couldn't parse the URL: %s" % url)
        url_filename, url_basename, gz_bz2 = m.groups()
    archive_dir = entry.get('archive_dir', url_basename)

    archive_path = os.path.join(BUILD_DIR, url_filename)
    if not os.path.exists(archive_path):
        download(url, archive_path)

    os.chdir(BUILD_DIR)
    sh("rm -rf '%s'" % archive_dir)
    sh("tar xf '%s'" % url_filename)

    if not os.path.exists(archive_dir):
        raise Exception('Tarball %s wasn\'t extracted into "%s"' % (url, archive_dir))

    os.chdir(archive_dir)
    cmd = entry.get('config_make_install', "%(pre_configure)s && ./configure '--prefix=%(LOCAL)s' %(configure_flags)s && nice -20 make -j 10 && make install")
    sh(cmd % dict(LOCAL=LOCAL, pre_configure=entry.get('pre_configure', 'true'), configure_flags=entry.get('configure_flags', ''))
    os.chdir(BUILD_DIR)
    sh("rm -rf '%s'" % archive_dir)

    print 'Installed %s' % url

###############################################################################

_page_cache = {}
def xorg(package):
    global _page_cache
    url = 'http://www.x.org/releases/X11R7.5/src/' + package
    if '.tar' in url:
        return url
    dir = os.path.dirname(url)
    if dir not in _page_cache:
        _page_cache[dir] = urllib2.urlopen(dir).read()
    page = _page_cache[dir]
    matches = re.findall('<a href="(%s-[^"]*.tar.bz2)">' % os.path.basename(package), page)
    if len(matches) != 1:
        raise Exception('Failed to find package %s (found %d matches on page %s)' % (
            os.path.basename(package), len(matches), dir))
    res = dir + '/' + matches[0]
    return dict(url=res)

def gnu(package, **extra):
    #return 'http://ftp.gnu.org/gnu/' + package
    return dict(url='http://mirrors.kernel.org/gnu/' + package, **extra)

PACKAGES = [
    # let's install some gnu tools to replace the junk shipped with bsd.
    gnu('make/make-3.81.tar.bz2', config_make_install="./configure '--prefix=%(LOCAL)s' && make && make install"),
    gnu('wget/wget-1.12.tar.bz2'),
    gnu('libiconv/libiconv-1.13.1.tar.gz'),
    gnu('gettext/gettext-0.17.tar.gz'),
    gnu('ncurses/ncurses-5.7.tar.gz'),
    gnu('gmp/gmp-5.0.1.tar.bz2'),
    gnu('tar/tar-1.23.tar.bz2'),
    gnu('coreutils/coreutils-8.4.tar.gz'),
    gnu('diffutils/diffutils-2.9.tar.gz'),
    gnu('findutils/findutils-4.4.2.tar.gz'),
    #gnu('patch/patch-2.6.1.tar.bz2'),
    gnu('grep/grep-2.6.1.tar.gz'),
    gnu('groff/groff-1.20.1.tar.gz'),
    gnu('m4/m4-1.4.14.tar.bz2'),
    gnu('sed/sed-4.2.1.tar.bz2'),
    gnu('gawk/gawk-3.1.7.tar.bz2'),
    gnu('bison/bison-2.4.2.tar.bz2'),
    dict(url='http://prdownloads.sourceforge.net/flex/flex-2.5.35.tar.bz2?download', url_filename='flex-2.5.35.tar.bz2', url_basename='flex-2.5.35'),

    gnu('gdb/gdb-7.1.tar.bz2'),
    gnu('gperf/gperf-3.0.4.tar.gz'),
    dict(url='http://www.kernel.org/pub/software/scm/git/git-1.7.0.tar.bz2', pre_configure='export PYTHON_PATH=$(which python)'),
    dict(url='http://downloads.sourceforge.net/project/netcat/netcat/0.7.1/netcat-0.7.1.tar.bz2'),
    dict(url='http://www.dest-unreach.org/socat/download/socat-1.7.1.2.tar.bz2'),
    dict(url='http://prdownloads.sourceforge.net/ctags/ctags-5.8.tar.gz'),
    dict(url='http://downloads.sourceforge.net/project/cscope/cscope/15.7a/cscope-15.7a.tar.bz2'),

    dict(url='http://xmlsoft.org/sources/libxml2-2.7.7.tar.gz'),
    dict(url='http://xmlsoft.org/sources/libxslt-1.1.26.tar.gz'),
    dict(url='http://pkgconfig.freedesktop.org/releases/pkg-config-0.23.tar.gz'),
    dict(url='http://ftp.gnome.org/pub/gnome/sources/glib/2.24/glib-2.24.0.tar.bz2'),
    dict(url='http://www.fontconfig.org/release/fontconfig-2.8.0.tar.gz'),
    dict(url='http://downloads.sourceforge.net/freetype/freetype-2.3.12.tar.bz2'),

    dict(url='http://www.ijg.org/files/jpegsrc.v8a.tar.gz', archive_dir='jpeg-8a'),
    dict(url='http://prdownloads.sourceforge.net/libpng/01-libpng-master/1.4.1/libpng-1.4.1.tar.bz2?download', url_filename='libpng-1.4.1.tar.bz2', url_basename='libpng-1.4.1'),
    dict(url='ftp://ftp.remotesensing.org/pub/libtiff/tiff-3.9.2.tar.gz'),

    # X11 libs
    xorg('proto/applewmproto'),
    xorg('proto/bigreqsproto'),
    xorg('proto/compositeproto'),
    xorg('proto/damageproto'),
    xorg('proto/dmxproto'),
    xorg('proto/dri2proto'),
    xorg('proto/fixesproto'),
    xorg('proto/fontsproto'),
    xorg('proto/glproto'),
    xorg('proto/inputproto'),
    xorg('proto/kbproto'),
    xorg('proto/randrproto'),
    xorg('proto/recordproto'),
    xorg('proto/renderproto'),
    xorg('proto/resourceproto'),
    xorg('proto/scrnsaverproto'),
    xorg('proto/videoproto'),
    xorg('proto/windowswmproto'),
    xorg('proto/xcmiscproto'),
    xorg('proto/xextproto'),
    xorg('proto/xf86bigfontproto'),
    xorg('proto/xf86dgaproto'),
    xorg('proto/xf86driproto'),
    xorg('proto/xf86vidmodeproto'),
    xorg('proto/xineramaproto'),
    xorg('proto/xproto'),
    xorg('lib/xtrans'),
    xorg('lib/libXau'),
    xorg('lib/libXdmcp'),
    dict(url='http://xcb.freedesktop.org/dist/xcb-proto-1.5.tar.bz2'),
    dict(url='http://xcb.freedesktop.org/dist/libpthread-stubs-0.1.tar.bz2'),
    dict(url='http://xcb.freedesktop.org/dist/libxcb-1.4.tar.bz2'),
    dict(url='http://xcb.freedesktop.org/dist/xcb-util-0.3.6.tar.bz2'),
    xorg('lib/libX11'),
    xorg('lib/libXext'),
    xorg('lib/libdmx'),
    xorg('lib/libfontenc'),
    xorg('lib/libFS'),
    xorg('lib/libICE'),
    xorg('lib/libSM'),
    xorg('lib/libXt'),
    xorg('lib/libXmu'),
    xorg('lib/libXpm'),
    xorg('lib/libXaw'),
    xorg('lib/libXfixes'),
    xorg('lib/libXcomposite'),
    xorg('lib/libXrender'),
    xorg('lib/libXdamage'),
    xorg('lib/libXcursor'),
    xorg('lib/libXfont'),
    xorg('lib/libXft'),
    xorg('lib/libXi'),
    xorg('lib/libXinerama'),
    xorg('lib/libxkbfile'),
    xorg('lib/libXrandr'),
    xorg('lib/libXres'),
    xorg('lib/libXScrnSaver'),
    xorg('lib/libXtst'),
    xorg('lib/libXv'),
    xorg('lib/libXvMC'),
    xorg('lib/libXxf86dga'),
    xorg('lib/libXxf86vm'),
    xorg('lib/libpciaccess'),
    #build pixman ""
    dict(url='http://xorg.freedesktop.org/releases/individual/data/xbitmaps-1.1.0.tar.bz2'),
    #dict(url='http://xorg.freedesktop.org/releases/individual/data/xcursor-themes-1.0.2.tar.bz2'),

    # X11 apps
    xorg('app/xauth'),
    xorg('app/xdpyinfo'),
    dict(url='http://www.x.org/releases/individual/app/xclock-1.0.4.tar.bz2'),
    dict(url='http://www.x.org/releases/individual/app/xeyes-1.1.0.tar.bz2'),
    dict(url='http://www.x.org/releases/individual/app/twm-1.0.4.tar.bz2'),
    dict(url='http://www.x.org/releases/individual/app/xlsfonts-1.0.2.tar.bz2'),
    dict(url='http://dist.schmorp.de/rxvt-unicode/Attic/rxvt-unicode-9.07.tar.bz2', configure_flags='--enable-everything'),
    dict(url='http://www.vergenet.net/~conrad/software/xsel/download/xsel-1.2.0.tar.gz',
        pre_configure="sed -i -e 's/-Werror/-Wno-error/' ./configure"),

    # GTK
    dict(url='http://cairographics.org/releases/pixman-0.17.14.tar.gz'),
    dict(url='http://cairographics.org/releases/cairo-1.8.10.tar.gz'),
    dict(url='http://ftp.gnome.org/pub/gnome/sources/atk/1.29/atk-1.29.92.tar.bz2'),
    dict(url='http://ftp.gnome.org/pub/gnome/sources/pango/1.27/pango-1.27.1.tar.bz2'),
    dict(url='http://ftp.gnome.org/pub/gnome/sources/gtk+/2.20/gtk+-2.20.0.tar.bz2'),

    dict(url='ftp://ftp.vim.org/pub/vim/unix/vim-7.2.tar.bz2',
        archive_dir="vim72",
        configure_flags='--with-features=huge --with-x --with-gui=gtk2 --enable-cscope --enable-multibyte --enable-pythoninterp --disable-nls'),

    # TODO: copy some fonts over to .local/share/fonts and create a symlink for it:
    # ln -s .local/share/fonts ~/.fonts
]

del gnu
del xorg

def main():
    for entry in PACKAGES:
        url = entry['url']
        package_id = entry.get('package_id', os.path.basename(url))
        if not is_installed(package_id):
            install_tarball(entry)
            mark_installed(package_id)

main()
