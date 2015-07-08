import os.path
import argparse
import urllib2
import shutil
from StringIO import StringIO
from zipfile import ZipFile

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

def unzip(url, outdir):
    zipfile = readzip(url)
    if zipfile is None and '.git' in url:
        i = url.rfind('.git')
        url0 = url[:i] + '/zipball/master' + url[i+4:]
        zipfile = readzip(url0)
    if zipfile is None and 'fileexchange' in url:
        zipfile = readzip(url + '?download=true')
    if zipfile is None:
        return False

    dirnames = set([os.path.normpath(x).split(os.sep)[0] for x in zipfile.namelist()])
    zipfile.extractall(outdir)
    if len(dirnames) == 1:
        basedir = os.path.join(outdir, list(dirnames)[0])
        copytree(basedir, outdir)
        # for f in os.listdir(basedir):
        #   shutil.copy2(os.path.join(basedir, f), outdir)
        shutil.rmtree(basedir)
    return True
    
def main(url, name, outdir, force):
    url = url.strip()
    name = name.strip()
    if not os.path.exists(outdir):
        raise Exception("Invalid MATLABDIR: {0}".format(outdir))
    outdir = os.path.join(outdir, name)
    if os.path.exists(outdir) and not force:
        print 'Package "{1}" already exists at {0}'.format(outdir, name)
        return
    status = unzip(url, outdir)
    if status:
        print 'Installed "{1}" to {0}'.format(outdir, name)
    else:
        print 'ERROR: Could not install "{0}"'.format(name)

def load_from_file(infile, outdir, force):
    with open(infile) as f:
        for line in f.readlines():
            line = line.strip()
            if '-e' not in line: continue
            name, _, url = line.partition('-e')
            main(url, name, outdir, force)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("-n", "--name", type=str, required=False, default=None, help="name of package")
    parser.add_argument("-r", "--reqsfile", type=str, required=False, default=None, help="path to requirements file")
    parser.add_argument("-e", "--url", type=str, required=False, default=None, help="url of package as zip")
    parser.add_argument("-o", "--outdir", type=str, default=MATLABDIR, help="installation directory")
    parser.add_argument("-f", "--force", action='store_true', default=False, help="overwrite if package already exists")
    args = parser.parse_args()
    if args.reqsfile:
        load_from_file(args.reqsfile, args.outdir, args.force)
    else:
        main(args.url, args.name, args.outdir, args.force)
