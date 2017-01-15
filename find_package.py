import urllib2
from lxml import etree
import imp

try:
    imp.find_module('github')
    from github import Github
except ImportError:
    # dummy constructor
    Github = lambda: True

def find_github_repo(query, handle=None, release_tag=None):
    """
    handle = Github()
    https://github.com/PyGithub/PyGithub
    https://developer.github.com/v3/repos/releases/
    """
    if handle is None:
        handle = Github()
    if not hasattr(handle, 'search_repositories'):
        # PyGithub not installed
        return
    rs = handle.search_repositories(query + 'language:matlab')
    try:
        repo = rs[0]
    except IndexError:
        return
    if release_tag is not None:
        # find release with matching tag
        rels = [t for t in repo.get_tags() if t.name == release_tag]
        if rels:
            return rels[0].zipball_url
        else:
            return
    try:
        # find latest release
        return get_zipball_from_url(repo, repo.url + '/releases/latest')
    except:
        return repo.html_url + '/zipball/master'

def get_zipball_from_url(repo, url):
    headers, data = repo._requester.requestJsonAndCheck("GET", url)
    return data['zipball_url']

def find_matlabcentral_repo(query):
    # http://www.mathworks.com/matlabcentral/fileexchange/22022-matlab2tikz-matlab2tikz
    query_html = urllib2.quote(query)
    url = 'http://www.mathworks.com/matlabcentral/fileexchange/?term={0}'.format(query_html)
    response = urllib2.urlopen(url)
    html = response.read()
    tree = etree.HTML(html)
    return tree.xpath('//a[@class="results_title"]')[0].get('href')
