
//
// Basic types
//

IntegerTypes :: Type.[s8, s16, s32, s64, u8, u16, u32, u64, int];
FloatTypes   :: Type.[float32, float64, float];

serialize :: (s: *ApSerializer, data: *$T/IntegerTypes, allocator := Allocator.{}) {
    if s.mode == .WRITING {
        serializer_write_data(s, data, size_of(T));
    } else if s.mode == .READING {
        serializer_read_data(s, data, size_of(T));
    }
}

serialize :: (s: *ApSerializer, data: *$T, allocator := Allocator.{})
#modify {
    info := cast (*Type_Info) T;
    return info.type == .ENUM;
} {
    enum_info := type_info(T);
    int_type := enum_info.internal_type;
    if int_type.runtime_size == {
    case 1; // s8, u8
        if int_type.signed {
            serialize(s, cast(*s8)data, allocator);
        } else {
            serialize(s, cast(*u8)data, allocator);
        }
    case 2; // s16, u16
        if int_type.signed {
            serialize(s, cast(*s16)data, allocator);
        } else {
            serialize(s, cast(*u16)data, allocator);
        }
    case 4; // s32, u32
        if int_type.signed {
            serialize(s, cast(*s32)data, allocator);
        } else {
            serialize(s, cast(*u32)data, allocator);
        }
    case 8; // s64, u64
       if int_type.signed {
            serialize(s, cast(*s64)data, allocator);
        } else {
            serialize(s, cast(*u64)data, allocator);
        }
    }
}

serialize :: (s: *ApSerializer, data: *bool, allocator := Allocator.{}) {
    if s.mode == .WRITING {
        serializer_write_data(s, data, size_of(bool));
    } else if s.mode == .READING {
        serializer_read_data(s, data, size_of(bool));
    }
}

serialize :: (s: *ApSerializer, data: *$T/FloatTypes, allocator := Allocator.{}) {
    if s.mode == .WRITING {
        serializer_write_data(s, data, size_of(T));
    } else if s.mode == .READING {
        serializer_read_data(s, data, size_of(T));
    }
}

serialize :: (s: *ApSerializer, data: *string, allocator := Allocator.{}) {
    if s.mode == .WRITING {
        serialize(s, *data.count, allocator);
        serializer_write_data(s, data.data, data.count * size_of(u8));
    } else if s.mode == .READING {
        assert(data.data == null, "Serializer only returns string allocated with 'temp', so provide it with an empty string on the stack, please. And do whatever afterwards.");
        
        count: int;
        serialize(s, *count, allocator);
        data.count = count;
        
        if count {
            temp_data := alloc(count * size_of(u8),, allocator);
            
            serializer_read_data(s, temp_data, count * size_of(u8));
            
            data.data = temp_data;
        }
    }
}

// 1D array
serialize :: (s: *ApSerializer, data: *[]$T, allocator := Allocator.{}) #modify {
    info := cast (*Type_Info) T;
    return info.type != .ARRAY;
} {
    
    if s.mode == .WRITING {
        serialize(s, *data.count, allocator);
        for 0..data.count-1 {
            serialize(s, *((data.*)[it]), allocator);
        }
    } else if s.mode == .READING {
        assert(data.data == null, "Serializer only returns arrays allocated with 'temp', so provide it with an empty string on the stack, please. And do whatever afterwards.");
        
        count: int;
        serialize(s, *count, allocator);
        data.count = count;
        
        if count {
            temp_data: [..] T;
            temp_data.allocator = allocator;
            for 0..count-1 {
                t: T;
                serialize(s, *t, allocator);
                
                array_add(*temp_data, t);
            }
            
            data.data = temp_data.data;
        }
    }
}

// 2D array
serialize :: (s: *ApSerializer, data: *[][]$T, allocator := Allocator.{}) #modify {
    info := cast (*Type_Info) T;
    return info.type != .ARRAY;
} {
    
    if s.mode == .WRITING {
    
        width := data.count;
        height := ifx width then data[0].count else 0;
        
        serialize(s, *width, allocator);
        serialize(s, *height, allocator);
        
        arr := << data;
        for ix: 0..width-1 {
            for iy: 0..height-1 {
                serialize(s, *arr[ix][iy], allocator);
                
            }
        }
    } else if s.mode == .READING {
        assert(data.data == null, "Serializer only returns arrays allocated with 'temp', so provide it with an empty string on the stack, please. And do whatever afterwards.");
        
        width: int;
        height: int;
        serialize(s, *width, allocator);
        serialize(s, *height, allocator);
        
        temp_data: [..][..] T;
        temp_data.allocator = allocator;
        for ix: 0..width-1 {
            arr: [..] T;
            for iy: 0..height-1 {
                t: T;
                serialize(s, *t, allocator);
                
                array_add(*arr, t);
            }
            array_add(*temp_data, arr);
        }
        
        data.data = temp_data.data;
        data.count = temp_data.count;
    }
}

serialize :: (s: *ApSerializer, data: *Bucket_Array($T, $C, $P), allocator := Allocator.{}) {
    if s.mode == .WRITING {
        count := data.count;
        
        serialize(s, *count, allocator);
        
        for * item: << data {
            serialize(s, item, allocator);
        }
    } else {
        count := 0;
        serialize(s, *count, allocator);
        
        for i: 0..count-1 {
            item, locator := find_and_occupy_empty_slot(data);
            
            serialize(s, item, allocator);
            
            item.locator = locator;
        }
    }
}

serialize :: (s: *ApSerializer, data: *Table($KEY, $VALUE), allocator := Allocator.{}) {
    if s.mode == .WRITING {
        count := data.count;
        
        serialize(s, *count, allocator);
        
        for value, key: data {
            serialize(s, *key, allocator);
            serialize(s, *value, allocator);
        }
    } else {
        count := 0;
        serialize(s, *count, allocator);
        
        for i: 0..count-1 {
            key: KEY;
            value: VALUE;
            
            serialize(s, *key, allocator);
            serialize(s, *value, allocator);
            
            table_set(data, key, value);
        }
    }
}

// fixed 1D array
serialize :: (s: *ApSerializer, data: *[$A]$T, allocator := Allocator.{}) #modify {
    info := cast (*Type_Info) T;
    return info.type != .ARRAY;
} {
    
    if s.mode == .WRITING {
        width  := cast(int) A;
        
        serialize(s, *width, allocator);
        
        arr := << data;
        for ix: 0..width-1 {
            serialize(s, *arr[ix], allocator);
        }
    } else if s.mode == .READING {
        width: int;
        
        serialize(s, *width, allocator);
        
        assert(width == A);
        
        for ix: 0..width-1 {
            serialize(s, *(<<data)[ix], allocator);
        }
    }
}

// fixed 2D array
serialize :: (s: *ApSerializer, data: *[$A][$B]$T, allocator := Allocator.{}) #modify {
    info := cast (*Type_Info) T;
    return info.type != .ARRAY;
} {
    
    if s.mode == .WRITING {
        width  := cast(int) A;
        height := cast(int) B;
        
        serialize(s, *width, allocator);
        serialize(s, *height, allocator);
        
        arr := << data;
        for ix: 0..width-1 {
            for iy: 0..height-1 {
                serialize(s, *arr[ix][iy], allocator);
            }
        }
    } else if s.mode == .READING {
        width: int;
        height: int;
        
        serialize(s, *width, allocator);
        serialize(s, *height, allocator);
        
        assert(width == A);
        assert(height == B);
        
        for ix: 0..width-1 {
            for iy: 0..height-1 {
                serialize(s, *(<<data)[ix][iy], allocator);
            }
        }
    }
}

serialize :: (s: *ApSerializer, data: *Vector2, allocator := Allocator.{}) {
    serialize(s, *data.x, allocator);
    serialize(s, *data.y, allocator);
}

serialize :: (s: *ApSerializer, data: *Vector3, allocator := Allocator.{}) {
    serialize(s, *data.x, allocator);
    serialize(s, *data.y, allocator);
    serialize(s, *data.z, allocator);
}

serialize :: (s: *ApSerializer, data: *Vector4, allocator := Allocator.{}) {
    serialize(s, *data.x, allocator);
    serialize(s, *data.y, allocator);
    serialize(s, *data.z, allocator);
    serialize(s, *data.w, allocator);
}

