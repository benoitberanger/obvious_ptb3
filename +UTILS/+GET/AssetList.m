function [fname, fpath] = AssetList()
logger = getLogger();

asset_dir = fullfile(UTILS.GET.RootDir(), 'assets');
logger.log('asset dir = %s', asset_dir);

video_ext = '.mp4';
d = fullfile(asset_dir,'**',['*' video_ext]);
assetdir_content = dir(d);

fname = {assetdir_content.name}';
fpath = fullfile({assetdir_content.folder},{assetdir_content.name})';

N = length(fname);
logger.assert(N, 'no file found with extension %s !', video_ext)

logger.log('found %d files',N);
end % fcn
