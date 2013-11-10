function [dictionary] = build_dictionary(filelist, feature, c)
if(~exist('c', 'var'))
  c = conf();
end

p = c.feature_config.(feature);
if(~isfield(p, 'dictionary_file'))
  dictionary = [];
  return;
end
p.dictionary_file = sprintf(p.dictionary_file, c.cache, p.dictionary_size);
found_dictionary = 0;
check_building = 0;

while(found_dictionary == 0)
  if(~exist(p.dictionary_file, 'file'))
    hostname = getComputerName();
    save(p.dictionary_file, 'hostname');
    
    %check for multiple datasets
    if(iscell(filelist{1}))
      trainlists = filelist;
      num_datasets = length(trainlists);
      images_per_dataset = ceil(p.num_images/num_datasets);
      filelists = cellfun(@(x) x(randperm(length(x), min(length(x), images_per_dataset))), trainlists, 'UniformOutput', false);
      filelist = {};
      for i=1:length(filelists)
        filelist = [filelist filelists{i}];
      end
    end
    
    perm = randperm(length(filelist));
    descriptors = cell(min(length(filelist), p.num_images), 1);
    num_images = min(length(filelist), p.num_images);
    parfor i=1:num_images
      fprintf('Dictionary learning (%s): %d of %d\n', feature, i, num_images);
      img = imgread(filelist{perm(i)}, p);
      feat = extract_feature(feature, img, c);
      r = randperm(size(feat, 1));
      descriptors{i} = feat(r(1:min(length(r), p.descPerImage)), :);
    end
    descriptors = cell2mat(descriptors);
    ndata = size(descriptors, 1);
    if(ndata>p.num_desc)
      idx = randperm(ndata);
      descriptors = descriptors(idx(1:p.num_desc), :);
    end
    fprintf('Running k-means, #samples = %d, #features = %d, dictionary size %d...', size(descriptors,1), size(descriptors,2), p.dictionary_size);
%     dictionary = litekmeans(descriptors', p.dictionary_size);
    dictionary = kmeansFast(descriptors, p.dictionary_size);
    fprintf('done!\n');
%     dictionary = dictionary';
    make_dir(p.dictionary_file);
    fprintf('Saving dictionary: %s\n', p.dictionary_file);
    save(p.dictionary_file, 'dictionary');
    found_dictionary = 1;
  else
    load(p.dictionary_file);
    if(~exist('dictionary', 'var'))
      if(check_building ==0)
        fprintf('Dictionary building in progress on %s..', hostname);
        check_building = 1;
      end
      fprintf('.');
      pause(5);
    else
      found_dictionary = 1;
      if(check_building==1)
        fprintf('\n');
      end
    end
  end
end
