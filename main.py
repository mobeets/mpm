import os.path
import argparse
from StringIO import StringIO
from zipfile import ZipFile
from urllib import urlopen
import shutil

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

def unzip(url, outdir):
    urlc = urlopen(url)
    zipfile = ZipFile(StringIO(urlc.read()))
    dirnames = set([os.path.normpath(x).split(os.sep)[0] for x in zipfile.namelist()])
    zipfile.extractall(outdir)
    if len(dirnames) == 1:
        basedir = os.path.join(outdir, list(dirnames)[0])
        copytree(basedir, outdir)
        # for f in os.listdir(basedir):
        #   shutil.copy2(os.path.join(basedir, f), outdir)
        shutil.rmtree(basedir)
    
def main(url, name, outdir, force):
    if not os.path.exists(outdir):
        raise Exception("Invalid MATLABDIR: {0}".format(outdir))
    outdir = os.path.join(outdir, name)
    if os.path.exists(outdir) and not force:
        print 'Package already exists at {0}'.format(outdir)
        return
    unzip(url, outdir)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("-n", "--name", type=str, required=True, default=None)
    parser.add_argument("-u", "--url", type=str, required=True, default=None)
    parser.add_argument("-o", "--outdir", type=str, default=MATLABDIR)
    parser.add_argument("-f", "--force", action='store_true', default=False)
    args = parser.parse_args()
    main(args.url, args.name, args.outdir, args.force)
