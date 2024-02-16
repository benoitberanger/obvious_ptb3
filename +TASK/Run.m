function Run()
global S


%% Keymap

KbName('UnifyKeyNames') % make keybinds cross-platform compatible

S.cfgKeybinds.Start = KbName('t');
S.cfgKeybinds.Abort = KbName('escape');
S.recKeylogger = UTILS.RECORDER.Keylogger(S.cfgKeybinds);
S.recKeylogger.Start();

%% start PTB engine

% get object
Window = PTB_ENGINE.VIDEO.Window();
S.Window = Window; % also save it in the global structure for diagnostic

% task specific paramters
S.Window.bg_color       = [0 0 0];
S.Window.movie_filepath = [S.OutFilepath '.mov'];

% set parameters from the GUI
S.Window.screen_id      = S.guiScreenID; % mandatory
S.Window.is_transparent = S.guiTransparent;
S.Window.is_windowed    = S.guiWindowed;
S.Window.is_recorded    = S.guiRecordMovie;

S.Window.Open();


%% Prepare movie

[S.moviePtr, S.movieDuration, S.movieFps, S.movieWidth, S.movieHeight, S.movieCount, S.movieAspectRatio, S.movieHdrStaticMetaData] = ...
    Screen('OpenMovie', Window.ptr, S.videoFullpath);


%% Prepare microphone recording


InitializePsychSound()

% Open audio device 'device', with mode 2 (== Only audio capture),
% and a required latencyclass of 1 == low-latency mode, with the preferred
% default sampling frequency of the audio device, and 2 sound channels
% for stereo capture. This returns a handle to the audio device:
device = [];
pahandle = PsychPortAudio('Open', device, 2, 1, [], 1);

% Get what freq'uency we are actually using:
s = PsychPortAudio('GetStatus', pahandle);
S.micFreq = s.SampleRate;

% Preallocate an internal audio recording  buffer with a capacity of 10 seconds:
PsychPortAudio('GetAudioData', pahandle, 10);

S.micData = zeros(1, round(S.movieDuration * S.micFreq * 1.10));
S.micSampleCount = 0;


%% Runtime

EXIT = false;
secs = GetSecs();

S.STARTtime = PTB_ENGINE.START(S.cfgKeybinds.Start, S.cfgKeybinds.Abort);

% Start audio capture immediately and wait for the capture to start.
% We set the number of 'repetitions' to zero,
% i.e. record until recording is manually stopped.
PsychPortAudio('Start', pahandle, 0, 0, 1);

rate = 1;
% Start playback of movie. This will start
% the realtime playback clock and playback of audio tracks, if any.
% Play 'movie', at a playbackrate = 1, with endless loop=1 and
% 1.0 == 100% audio volume.
Screen('PlayMovie', S.moviePtr, rate, 0, 1.0);

while 1
    [keyIsDown, secs, keyCode] = KbCheck();
    if keyIsDown
        EXIT = keyCode(S.cfgKeybinds.Abort);
        if EXIT, break, end
    end

    % Return next frame in movie, in sync with current playback
    % time and sound.
    % tex is either the positive texture handle or zero if no
    % new frame is ready yet in non-blocking mode (blocking == 0).
    % It is -1 if something went wrong and playback needs to be stopped:
    tex = Screen('GetMovieImage', Window.ptr, S.moviePtr);

    % Valid texture returned?
    if tex < 0
        % No, and there won't be any in the future, due to some
        % error. Abort playback loop:
        break;
    end

    if tex == 0
        % No new frame in polling wait (blocking == 0). Just sleep
        % a bit and then retry.
        WaitSecs('YieldSecs', 0.005);
        continue;
    end

    % Draw the new texture immediately to screen:
    Screen('DrawTexture', Window.ptr, tex, [], []);

    % Update display:
    Screen('Flip', Window.ptr);

    % Release texture:
    Screen('Close', tex);

    % Retrieve pending audio data from the drivers internal ringbuffer:
    audiodata = PsychPortAudio('GetAudioData', pahandle);
    nrsamples = length(audiodata);
    S.micData(S.micSampleCount+1 : S.micSampleCount+nrsamples) = audiodata;
    S.micSampleCount = S.micSampleCount + nrsamples;

end

% if Abort is pressed
if EXIT
    if S.WriteFiles
        save([S.OutFilepath '__ABORT_at_runtime.mat'], 'S')
    end
    fprintf('!!! @%s : Abort key received !!!\n', mfilename)
end

S.ENDtime = GetSecs();

Screen('Flip', Window.ptr);

% Done. Stop playback:
Screen('PlayMovie', S.moviePtr, 0);

% Close movie object:
Screen('CloseMovie', S.moviePtr);

% Stop capture:
PsychPortAudio('Stop', pahandle);
audiodata = PsychPortAudio('GetAudioData', pahandle);
nrsamples = length(audiodata);
S.micData(S.micSampleCount+1 : S.micSampleCount+nrsamples) = audiodata;
S.micSampleCount = S.micSampleCount + nrsamples;

S.micData = S.micData(1:S.micSampleCount); % trim

% Close the audio device:
PsychPortAudio('Close', pahandle);

PTB_ENGINE.END();


%% End of task routine

S.Window.Close();

S.recKeylogger.GetQueue();
S.recKeylogger.Stop();
S.recKeylogger.kb2data();
switch S.guiACQmode
    case 'Acquisition'
    case {'Debug', 'FastDebug'}
        TR = CONFIG.TR();
        n_volume = ceil((S.ENDtime-S.STARTtime)/TR);
        S.recKeylogger.GenerateMRITrigger(TR, n_volume, S.STARTtime)
end
S.recKeylogger.ScaleTime(S.STARTtime);
assignin('base', 'S', S)

switch S.guiACQmode
    case 'Acquisition'
    case {'Debug', 'FastDebug'}
end


end % fcn
