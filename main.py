import os.path
import argparse
from StringIO import StringIO
from zipfile import ZipFile
from urllib import urlopen
import shutil

EXAMPLE_URL_1 = "http://www.mathworks.com/matlabcentral/fileexchange/23629-export-fig?download=true"
EXAMPLE_URL_2 = "http://www.mathworks.com/matlabcentral/fileexchange/downloads/9937/akamai/gridfitdir.zip"
EXAMPLE_URL_3 = "https://codeload.github.com/altmany/export_fig/legacy.zip/master"

HOMEDIR = os.path.expanduser("~")
MATLABDIR = os.path.join(HOMEDIR, 'Documents', 'MATLAB')

def unzip(url, outdir):
	urlc = urlopen(url)
	zipfile = ZipFile(StringIO(urlc.read()))
	dirnames = set([os.path.normpath(x).split(os.sep)[0] for x in zipfile.namelist()])
	zipfile.extractall(outdir)
	if len(dirnames) == 1:
		basedir = os.path.join(outdir, list(dirnames)[0])
		for f in os.listdir(basedir):
			shutil.copy2(os.path.join(basedir, f), outdir)
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
    parser.add_argument("name", type=str, default=None)
    parser.add_argument("-u", "--url", type=str, required=True, default=None)
    parser.add_argument("-o", "--outdir", type=str, default=MATLABDIR)
    parser.add_argument("-f", "--force", action='store_true', default=False)
    args = parser.parse_args()
    main(args.url, args.name, args.outdir, args.force)
