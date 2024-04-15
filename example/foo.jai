
#import "Basic";
// #import,file "../module.jai"()(Version_Type = Game_Version);
#load "../module.jai";

#import "Math";
#import "Bucket_Array";

Game_Version :: enum s64 {
    not_inited :: 0;
    
    ap_test;
}

Bar :: struct {
    d: s32;
    s: s32;
}

Foo :: struct {
    t: [8] Bar;
    v: s16;
    t2: [8] Bar;
}

main :: () {
    print("\n\n\n\n\n\n");
        
    write_test();
    
    read_test();
}

serialize :: (s: *ApSerializer, data: *Foo) {
    ADD(.ap_test, "t");
    ADD(.ap_test, "v");
    ADD(.ap_test, "t2");
}

serialize :: (s: *ApSerializer, data: *[8]Bar, allocator := Allocator.{}) {
    if s.mode == .WRITING {
        serializer_write_data(s, data.data, size_of(Bar)* data.count);
    } else {
        serializer_read_data(s,  data.data, size_of(Bar)* data.count);
    }
}




#import "Hash_Table";

#scope_file 
write_test :: () {
    s := start_serializing(.WRITING, "foo.data");
    
    value: Foo;
    value.t[0].s = 1;
    value.t[1].s = 2;
    value.t[2].s = 4;
    value.v = 3333;
    value.t2[0].s = 4;
    value.t2[1].s = 1;
    value.t2[2].s = 2;
    
    for i: 0..100 {
        serialize(*s, *value);
    }
    
    end_serializing(*s);
    
    print("% %\n", size_of([8]Bar), size_of(Bar) * 8);
    print("%\n", value);
}

read_test :: () {
    s := start_serializing(.READING, "foo.data");
    
    value: Foo;
    serialize(*s, *value);
    
    serialize(*s, *value);
    
    serialize(*s, *value);
    
    end_serializing(*s);
    print("%\n", value);
}