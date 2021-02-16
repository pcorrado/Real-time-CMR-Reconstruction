function divideSlices(pathname, nCoils, nSlices, readoutLength, spokesPerSlice, spokesPerFrame)
    for slice = 1:nSlices % Loop through slices
        fprintf('Slice %i of %i\n', slice, nSlices);
        sliceDir = sprintf('%s/Slices/Slice_%i', pathname, slice);
        mkdir(sliceDir);

        % Read BART data and reshape it
        filename = fullfile(pathname, 'MRI_Raw_Bart_data');
        data = readcfl(filename);
        nEnc=size(data,5);
        data = reshape(data,[1,readoutLength,(spokesPerSlice*nSlices),nCoils,1,nEnc,1,1,1,1,1]);

        % Grab the appropriate slice and reshape back
        data = data(:,:,(1:spokesPerSlice)+(slice-1)*spokesPerSlice,:,:,:,:,:,:,:,:);
        data = reshape(data,[1,1,readoutLength*spokesPerSlice,nCoils,1,nEnc,1,1,1,1,1]);

        % Read BART trajectory and reshape it
        filename = fullfile(pathname, 'MRI_Raw_Bart_traj');
        traj = readcfl(filename);
        traj = reshape(traj,[3,readoutLength,(spokesPerSlice*nSlices),1,1,nEnc,1,1,1,1,1,1]);

        % Grab the appropriate slice and reshape back
        traj = traj(:,:,(1:spokesPerSlice)+(slice-1)*spokesPerSlice,:,:,:,:,:,:,:,:);
        traj = reshape(traj,[3,1,readoutLength*spokesPerSlice,1,1,nEnc,1,1,1,1,1,1]);
        traj(3,:,:,:,:,:,:,:,:,:,:) = 0;

        % Write static (i.e. not time-resolved) data
        writecfl(fullfile(sliceDir,'kdata_static'),data);
        writecfl(fullfile(sliceDir,'traj_static'),traj);

        for iii = 1:numel(spokesPerFrame) % For each temporal resolution
            nSpokes = spokesPerFrame(iii);
            spokesDir = sprintf('%s/%i_spokes',sliceDir, nSpokes);
            mkdir(spokesDir);
            nT = floor(spokesPerSlice/nSpokes); % Number of frames

            % Reshape the data so that time is the 11th dimension (as per BART)
	          trajS = traj(:,:,1:(readoutLength*nSpokes*nT),:,:,:,:,:);
            trajS = reshape(trajS,[3,1,readoutLength*nSpokes,nT,1,1,nEnc]);
            trajS = permute(trajS, [1,2,3,5,6,7,8,9,10,11,4]);
            trajS = trajS(:,:,:,:,:,:,:,:,:,:,5:nT);

	          dataS = data(:,:,1:(readoutLength*nSpokes*nT),:,:,:,:,:,:,:);
            dataS = reshape(dataS,[1,1,readoutLength*nSpokes,nT,nCoils,1,nEnc]);
            dataS = permute(dataS, [1,2,3,5,6,7,8,9,10,11,4]);
            dataS = dataS(:,:,:,:,:,:,:,:,:,:,5:nT);

            % Write the data
            writecfl(fullfile(spokesDir,'kdata'),dataS);
            writecfl(fullfile(spokesDir,'traj'),trajS);
        end
    end
end
