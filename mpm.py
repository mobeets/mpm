import sys
import os.path
import argparse
import urllib2
import shutil
import tempfile
from subprocess import call
from StringIO import StringIO
from zipfile import ZipFile
from find_package import find_github_repo, find_matlabcentral_repo

HOMEDIR = os.path.expanduser("~")
MATLABDIR = os.path.join(HOMEDIR, 'Documents', 'MATLAB')

def copytree(src, dst, symlinks=False, ignore=None):
    for item in os.listdir(src):
        s = os.path.join(src, item)
        d = os.path.join(dst, item)
        if os.path.isdir(s):
            shutil.copytree(s, d, symlinks, ignore)
        else:
            shutil.copy2(s, d)

def readzip(url):
    try:
        urlc = urllib2.urlopen(url)
        return ZipFile(StringIO(urlc.read()))
    except Exception, e:
        # print url, e
        return
    # except urllib2.HTTPError, e:
    #     print e.code
    #     return
    # except urllib2.URLError, e:
    #     print e.args
    #     return

def unzip(url, outdir, allow_nesting):
    zipfile = readzip(url)
    if zipfile is None and '.git' in url:
        i = url.rfind('.git')
        url0 = url[:i] + '/zipball/master' + url[i+4:]
        zipfile = readzip(url0)
        if zipfile is None:
            zipfile = readzip(url + '/zipball/master')
    if zipfile is None and 'fileexchange' in url:
        zipfile = readzip(url + '?download=true')
    if zipfile is None:
        return False

    dirnames = set([os.path.normpath(x).split(os.sep)[0] for x in zipfile.namelist()])
    if os.path.exists(outdir):
        tmppath = tempfile.mkdtemp()
        copytree(outdir, tmppath)
        shutil.rmtree(outdir)
    try:
        zipfile.extractall(outdir)
        if allow_nesting:
            return True
        if len(dirnames) == 1 or (len(dirnames) == 2 and 'license.txt' in dirnames):
            basedir = os.path.join(outdir, list(dirnames)[0])
            copytree(basedir, outdir)
            # for f in os.listdir(basedir):
            #   shutil.copy2(os.path.join(basedir, f), outdir)
            shutil.rmtree(basedir)
        return True
    except:
        copytree(tmppath, outdir)
        return False
    
def find_package(name, githubfirst=False, version=None):
    if version is not None:
        return find_github_repo(name, release_tag=version)
    if githubfirst:
        url = find_github_repo(name)
        if url is None:
            url = find_matlabcentral_repo(name)
    else:
        url = find_matlabcentral_repo(name)
        if url is None:
            url = find_github_repo(name)
    return url

def main(url, name, outdir, force, allow_nesting, internaldir, searchonly, githubfirst, version):
    if url is None:
        url = find_package(name, githubfirst, version)
        if url is None:
            if version is None:
                print "Could not find any package named '{0}' on Github or Matlab FileExchange.".format(name)
            else:
                print "Could not find any package named '{0}' on Github with version {1}.".format(name, version)
            return
        if searchonly:
            print 'Package "{0}" found at "{1}". Not installing.'.format(name, url)
            return
        else:
            print 'Package "{0}" found at "{1}".'.format(name, url)
            return
    url = url.strip()
    name = name.strip()
    if not os.path.exists(outdir):
        raise Exception("Invalid MATLABDIR: {0}".format(outdir))
    outdir = os.path.join(outdir, name)
    if os.path.exists(outdir) and not force:
        print 'Package "{1}" already exists at {0}'.format(outdir, name)
        return
    status = unzip(url, outdir, allow_nesting)
    if status:
        print 'Installed "{1}" to {0}'.format(outdir, name)
    else:
        print 'ERROR: Could not install "{0}"'.format(name)

def check_args_in_file(args, i):
    msgs = []
    if args.count('-s') or args.count('--searchonly'):
        arg = '-s' if args.count('-s') else '--searchonly'
        msg = 'Ignoring {0} option in line {1}'.format(arg, i)
        msgs.append(msg)
    if args.count('-f') or args.count('--force'):
        arg = '-f' if args.count('-f') else '--force'
        msg = 'Ignoring {0} option in line {1}'.format(arg, i)
        msgs.append(msg)
    if args.count('-i') or args.count('--installdir'):
        arg = '-i' if args.count('-i') else '--installdir'
        msg = 'Ignoring {0} option in line {1}'.format(arg, i)
        msgs.append(msg)
    return msgs

def load_from_file(infile, outdir, force, searchonly):
    curdir = os.path.dirname(os.path.abspath(__file__))
    mpmpath = os.path.join(curdir, 'mpm.py')
    extra_args = ''
    if outdir:
        extra_args += ' --installdir ' + outdir
    if force:
        extra_args += ' --force'
    if searchonly:
        extra_args += ' --searchonly'
    with open(infile) as f:
        for i, line in enumerate(f.readlines()):
            args = line.split()
            msgs = check_args_in_file(args, i+1)
            for msg in msgs:
                print 'WARNING: ' + msg
            args += extra_args.split()
            print ' '.join(args)
            continue
            call(['python', mpmpath] + args)

def check_args(args):
    msgs = []
    if not args.reqsfile and not args.name:
        msg = "Must provide a package name"
        msgs.append(msg)
    if args.reqsfile and args.version:
        msg = "Specifying a version is not allowed when loading from requirements file."
        msgs.append(msg)
    if args.reqsfile and args.internaldir:
        msg = "Specifying an internaldir is illegal when loading from requirements file."
        msgs.append(msg)
    if args.reqsfile and args.githubfirst:
        msg = "Specifying to search githubfirst is illegal when loading from requirements file."
        msgs.append(msg)
    return msgs

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("name", nargs="?", type=str, default=None, help="name of package")
    parser.add_argument("url", nargs="?", type=str, default=None, help="url of package as zip")
    parser.add_argument("-r", "--reqsfile", type=str, required=False, default=None, help="path to requirements file")
    parser.add_argument("-i", "--installdir", type=str, default=MATLABDIR, help="installation directory")
    parser.add_argument("-f", "--force", action='store_true', default=False, help="overwrite if package already exists")
    parser.add_argument("--allow-nesting", action='store_true', default=False, help="prevent trying to un-nest packages")
    parser.add_argument("-n", "--internaldir", type=str, required=False, default=None, help="add internal directory to path instead")
    parser.add_argument("-s", "--searchonly", action='store_true', default=False, help="search only (no install)")
    parser.add_argument("-g", "--githubfirst", action='store_true', default=False, help="check github before matlab fileexchange")
    parser.add_argument("-v", "--version", type=str, required=False, default=None, help="attempt t find particular release version on Github")
    args = parser.parse_args()
    msgs = check_args(args)
    if msgs:
        parser.print_help()
        for msg in msgs:
            print msg
        sys.exit(1)
    if args.reqsfile:        
        load_from_file(args.reqsfile, args.installdir, args.force, args.searchonly)
    else:        
        main(args.url, args.name, args.installdir, args.force, args.allow_nesting, args.internaldir, args.searchonly, args.githubfirst, args.version)
