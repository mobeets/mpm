import sys
import glob
import json
import os.path
import argparse
import urllib2
import shutil
import tempfile
from datetime import datetime
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

def write_to_mpmfile(outdir, data, filename='mpm.json'):
    mpmfile = os.path.join(outdir, filename)
    if os.path.exists(mpmfile):
        with open(mpmfile) as f:
            objs = json.load(f)
    else:
        objs = []
    cur_ind = [i for i,x in enumerate(objs) if x['name'] == data['name']]
    if cur_ind:
        print 'Overwriting entry for "{0}" in mpmfile'.format(data['name'])
        objs[cur_ind[0]] = data
    else:
        objs.append(data)
    with open(mpmfile, 'w') as f:
        json.dump(objs, f, sort_keys=False, indent=4, separators=(',', ': '))

M_DIR_ORDER = ['bin', 'src', 'lib', 'code']
def find_mfile_dir(indir, internaldir=None, dirs_to_check=M_DIR_ORDER):
    mfls = glob.glob(os.path.join(indir, '*.m'))
    mfls += glob.glob(os.path.join(indir, '+*'))
    if mfls: # .m files in main dir -- all is well
        if internaldir is not None:
            print 'WARNING: Ignoring internaldir "{0}"" because .m files were found in the base directory'.format(internaldir)
        return indir
    if internaldir is not None:
        cdir = os.path.join(indir, internaldir)
        if not os.path.exists(cdir):
            print 'WARNING: Ignoring internaldir "{0}"" because it did not exist.'.format(internaldir)
        else:
            dirs_to_check = [internaldir]
    for cdir in dirs_to_check:
        cdr = os.path.join(indir, cdir)
        if not os.path.exists(cdr):
            continue
        if not glob.glob(os.path.join(cdr, '*.m')):
            continue
        # found a dir with .m files! keep this one
        return cdr
    # todo: search for any other dir with *.m in it
    print 'WARNING: No .m files will be added to path'
    return indir

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
            if 'license.txt' in dirnames:
                dirnames.remove('license.txt')
            basedir = os.path.join(outdir, list(dirnames)[0])
            if not os.path.isdir(basedir):
                return True
            copytree(basedir, outdir)
            # for f in os.listdir(basedir):
            #   shutil.copy2(os.path.join(basedir, f), outdir)
            shutil.rmtree(basedir)
        return True
    except Exception, e:
        print e
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
    print 'Package "{0}" found at "{1}".'.format(name, url)
    if searchonly:
        print 'Not installing "{0}" because user specified "searchonly".'.format(name)
        return
    url = url.strip()
    name = name.strip()
    if not os.path.exists(outdir):
        raise Exception("Invalid MATLABDIR: {0}".format(outdir))
    pckdir = os.path.join(outdir, name)
    if os.path.exists(pckdir) and not force:
        print 'Package "{1}" already exists at {0}'.format(pckdir, name)
        return
    status = unzip(url, pckdir, allow_nesting)
    if status:
        mdir = find_mfile_dir(pckdir, internaldir)
        print 'Installed "{1}" to {0}'.format(pckdir, name)
        print 'Will add "{0}" to path.'.format(mdir)       
        data = {'name': name, 'url': url, 'date_downloaded': str(datetime.now()), 'mdir': mdir}
        write_to_mpmfile(outdir, data)
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

def load_from_file(infile, outdir, force, searchonly, pythonexe='python'):
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
            if not line.strip(): # empty line
                continue
            args = line.split()
            msgs = check_args_in_file(args, i+1)
            for msg in msgs:
                print 'WARNING: ' + msg
            args += extra_args.split()
            call([pythonexe, mpmpath] + args)

def check_args(args):
    msgs = []
    if not args.reqsfile and not args.name:
        msg = "Must provide a package name"
        print args
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
    parser.add_argument("--pythonexe", type=str, required=False, default='python', help="specify which python to call (only relevant if reqts file set)")
    args = parser.parse_args()
    msgs = check_args(args)
    if msgs:
        parser.print_help()
        for msg in msgs:
            print msg
        sys.exit(1)    
    if args.reqsfile:        
        load_from_file(args.reqsfile, args.installdir, args.force, args.searchonly, args.pythonexe)
    else:
        main(args.url, args.name, args.installdir, args.force, args.allow_nesting, args.internaldir, args.searchonly, args.githubfirst, args.version)
