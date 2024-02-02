function video_name  = Video( handles )
all_videos     = get(handles.listbox_video, 'String');
selected_value = get(handles.listbox_video, 'Value' );
video_name     = all_videos{selected_value};
end % function