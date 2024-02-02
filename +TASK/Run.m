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

[moviePtr, duration, fps, width, height, count, aspectRatio, hdrStaticMetaData] = Screen('OpenMovie', Window.ptr, S.videoFullpath);



%% Runtime

EXIT = false;
secs = GetSecs();

S.STARTtime = PTB_ENGINE.START(S.cfgKeybinds.Start, S.cfgKeybinds.Abort);

rate = 1;
% Start playback of movie. This will start
% the realtime playback clock and playback of audio tracks, if any.
% Play 'movie', at a playbackrate = 1, with endless loop=1 and
% 1.0 == 100% audio volume.
Screen('PlayMovie', moviePtr, rate, 1, 1.0);

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
    tex = Screen('GetMovieImage', Window.ptr, moviePtr);

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

end

% if Abort is pressed
if EXIT

    S.ENDtime = GetSecs();

    if S.WriteFiles
        save([S.OutFilepath '_ABORT_at_runtime.mat'], 'S')
    end

    fprintf('!!! @%s : Abort key received !!!\n', mfilename)

end

Screen('Flip', Window.ptr);

% Done. Stop playback:
Screen('PlayMovie', moviePtr, 0);

% Close movie object:
Screen('CloseMovie', moviePtr);


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
