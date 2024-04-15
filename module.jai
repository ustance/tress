
#load "serializers.jai";

// Game_Version should be imported from outside

ApSerializer :: struct {
    mode: enum { WRITING; READING; };
    version: Game_Version;
    
    path: string;
    
    raw_data: *void;
    count: int = 0;
    size: int = 16 * 1024 * 1024;
    
    integrity_check: s32;
}

serializer_write_data :: (s: *ApSerializer, data: *void, size: s64) {
    if size == 0 return;
    
    if s.count + size >= s.size {
        new_size := (s.size + size) * 2;
        s.raw_data = realloc(s.raw_data, new_size, s.size);
        assert(s.raw_data != null);
        s.size = new_size;
    }
    
    memcpy(s.raw_data + s.count, data, size);
    s.count += size;
}

serializer_read_data :: (s: *ApSerializer, data: *void, size: s64) {
    if size == 0 return;
    
    memcpy(data, s.raw_data + s.count, size);
    s.count += size;
}

start_serializing :: (mode: type_of(ApSerializer.mode), path: string) -> ApSerializer, bool {
    s: ApSerializer;
    s.mode = mode;
    s.path = path;
    
    if mode == .WRITING {
        s.raw_data = alloc(s.size);
        
        latest := cast(s64) LATEST_VERSION;
        serialize(*s, *latest);
        s.version = LATEST_VERSION;
    } else {
        str := read_entire_file(path);
        s.raw_data = str.data;
        s.size = str.count;
        
        value: s64;
        serialize(*s, *value);
        s.version = xx value;
    }
    
    return s, true;
}

end_serializing :: (s: *ApSerializer) {
    str: string;
    str.data = s.raw_data;
    str.count = s.count;
    write_entire_file(s.path, str);
    
    free(s.raw_data);
}

//
// "Macros"
//

ADD :: (added_time: Game_Version, $field: string, allocator := Allocator.{}) #expand {
    if `s.version >= added_time {
        #insert #run tprint("t := *`data.%;", field);
        serialize(`s, t, allocator);
    }
}

CHECK_VERSION :: (added_time: Game_Version) -> bool #expand {
    return `s.version >= added_time;
}

CHECK_VERSION :: (added_time: Game_Version, removed_time: Game_Version) -> bool #expand {
    return `s.version >= added_time && `s.version < removed_time;
}

REM :: (added_time: Game_Version, removed_time: Game_Version, $T: Type, allocator := Allocator.{}) -> T, bool #expand {
    local: T;
    read: bool;
    if `s.version >= added_time && `s.version < removed_time {
        serialize(`s, *local, allocator);
        read = true;
    }
    return local, read;
}

CHECK_INTEGRITY :: (added_check: Game_Version) #expand {
    if `s.version >= added_check {
        check := `s.integrity_check;
        serialize(`s, *check);
        assert(check == `s.integrity_check);
        `s.integrity_check += 1;
    }
}

ADD_LOCAL :: (added_time: Game_Version, $field: string, allocator := Allocator.{}) #expand {
    T :: #insert #run tprint("type_of(`data.%);", field);
    #insert #run tprint("`%: T;", field);
    
    if `s.version >= added_time {
        if `s.mode == {
        case .WRITING;
            #insert #run tprint("t := *`data.%;", field);
            serialize(`s, t, allocator);
        case .READING;
            #insert #run tprint("t := *%;", field);
            serialize(`s, t, allocator);
        }
    }
}


#scope_file 

#import "File";

LATEST_VERSION :: #run () -> Game_Version {
    enum_info := type_info(Game_Version);
    
    return xx enum_info.values[enum_info.values.count-1];
}();