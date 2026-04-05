/*
 *   cbloomfilter.c - simple Bloom Filter
 *   (c) Tatsuya Mori <valdzone@gmail.com>
 */

#include "ruby.h"
#include "crc32.h"

#if !defined(RSTRING_LEN)
# define RSTRING_LEN(x) (RSTRING(x)->len)
# define RSTRING_PTR(x) (RSTRING(x)->ptr)
#endif

/* Reuse the standard CRC table for consistent salts */
static unsigned int *salts = crc_table;

static VALUE cBloomFilter;

struct BloomFilter {
    int m; /* # of bits in a bloom filter */
    int k; /* # of hash functions */
    unsigned char *ptr; /* bits data */
    int bytes; /* size of byte data */
};

unsigned long djb2(const char *str, int len) {
    unsigned long hash = 5381;
    for (int i = 0; i < len; i++) {
        hash = ((hash << 5) + hash) + str[i];
    }
    return hash;
}

static void bf_free(void *ptr) {
    struct BloomFilter *bf = ptr;

    if (bf == NULL) {
        return;
    }

    ruby_xfree(bf->ptr);
    ruby_xfree(bf);
}

static size_t bf_memsize(const void *ptr) {
    const struct BloomFilter *bf = ptr;

    if (bf == NULL) {
        return 0;
    }

    return sizeof(*bf) + (bf->ptr == NULL ? 0 : (size_t) bf->bytes);
}

static const rb_data_type_t bf_type = {
    "CBloomFilter",
    {0, bf_free, bf_memsize,},
    0, 0, RUBY_TYPED_FREE_IMMEDIATELY,
};

static struct BloomFilter *bf_ptr(VALUE obj) {
    struct BloomFilter *bf;

    TypedData_Get_Struct(obj, struct BloomFilter, &bf_type, bf);

    return bf;
}

static VALUE bf_alloc(VALUE klass) {
    struct BloomFilter *bf;
    VALUE obj = TypedData_Make_Struct(klass, struct BloomFilter, &bf_type, bf);

    bf->m = 0;
    bf->k = 0;
    bf->ptr = NULL;
    bf->bytes = 0;

    return obj;
}

static void bucket_set(struct BloomFilter *bf, int index) {
    int byte_offset = index / 8;
    int bit_offset = index % 8;

    bf->ptr[byte_offset] |= (unsigned char) (1U << bit_offset);
}

static int bucket_check(struct BloomFilter *bf, int index) {
    int byte_offset = index / 8;
    int bit_offset = index % 8;

    return (bf->ptr[byte_offset] >> bit_offset) & 1;
}

static VALUE bf_initialize(int argc, VALUE *argv, VALUE self) {
    struct BloomFilter *bf;
    VALUE arg1, arg2;
    int m, k;

    bf = bf_ptr(self);

    /* defaults */
    arg1 = INT2FIX(1000);
    arg2 = INT2FIX(4);

    switch (argc) {
        case 2:
      arg2 = argv[1];
        case 1:
      arg1 = argv[0];
      break;
    }

    m = FIX2INT(arg1);
    k = FIX2INT(arg2);

    if (m < 1)
        rb_raise(rb_eArgError, "array size");
    if (k < 1)
        rb_raise(rb_eArgError, "hash length");

    bf->m = m;
    bf->k = k;

    ruby_xfree(bf->ptr);
    bf->ptr = NULL;
    bf->bytes = 0;
    /* Preserve the existing serialized bitmap length, including one padding byte. */
    bf->bytes = (m + 15) / 8;
    bf->ptr = ALLOC_N(unsigned char, bf->bytes);

    /* initialize the bits with zeros */
    memset(bf->ptr, 0, bf->bytes);
    rb_iv_set(self, "@hash_value", rb_hash_new());

    return self;
}

static VALUE bf_clear(VALUE self) {
    struct BloomFilter *bf = bf_ptr(self);
    memset(bf->ptr, 0, bf->bytes);
    return Qtrue;
}

static VALUE bf_m(VALUE self) {
    struct BloomFilter *bf = bf_ptr(self);
    return INT2FIX(bf->m);
}

static VALUE bf_k(VALUE self) {
    struct BloomFilter *bf = bf_ptr(self);
    return INT2FIX(bf->k);
}

static VALUE bf_set_bits(VALUE self){
    struct BloomFilter *bf = bf_ptr(self);
    int i,j,count = 0;
    for (i = 0; i < bf->bytes; i++) {
        for (j = 0; j < 8; j++) {
            count += (bf->ptr[i] >> j) & 1;
        }
    }
    return INT2FIX(count);
}

static VALUE bf_add(VALUE self, VALUE key) {
    VALUE skey;
    unsigned long hash;
    int index;
    int i, len, m, k;
    char *ckey;
    struct BloomFilter *bf = bf_ptr(self);

    skey = rb_obj_as_string(key);
    ckey = StringValuePtr(skey);
    len = (int) (RSTRING_LEN(skey)); /* length of the string in bytes */

    m = bf->m;
    k = bf->k;

    hash = (unsigned long) djb2(ckey, len);
    for (i = 0; i <= k - 1; i++) {
        index = (int) ((hash ^ salts[i]) % (unsigned int) (m));

        /*  set a bit at the index */
        bucket_set(bf, index);
    }

    return Qnil;
}

static VALUE bf_merge(VALUE self, VALUE other) {
    struct BloomFilter *bf = bf_ptr(self);
    struct BloomFilter *target = bf_ptr(other);
    int i;
    for (i = 0; i < bf->bytes; i++) {
        bf->ptr[i] |= target->ptr[i];
    }
    return Qnil;
}

static VALUE bf_and(VALUE self, VALUE other) {
    struct BloomFilter *bf = bf_ptr(self);
    struct BloomFilter *bf_other = bf_ptr(other);
    struct BloomFilter *target;
    VALUE klass, obj, args[5];
    int i;

    args[0] = INT2FIX(bf->m);
    args[1] = INT2FIX(bf->k);
    klass = rb_funcall(self,rb_intern("class"),0);
    obj = rb_class_new_instance(2, args, klass);
    target = bf_ptr(obj);
    for (i = 0; i < bf->bytes; i++){
        target->ptr[i] = bf->ptr[i] & bf_other->ptr[i];
    }

    return obj;
}

static VALUE bf_or(VALUE self, VALUE other) {
    struct BloomFilter *bf = bf_ptr(self);
    struct BloomFilter *bf_other = bf_ptr(other);
    struct BloomFilter *target;
    VALUE klass, obj, args[5];
    int i;

    args[0] = INT2FIX(bf->m);
    args[1] = INT2FIX(bf->k);
    klass = rb_funcall(self,rb_intern("class"),0);
    obj = rb_class_new_instance(2, args, klass);
    target = bf_ptr(obj);
    for (i = 0; i < bf->bytes; i++){
        target->ptr[i] = bf->ptr[i] | bf_other->ptr[i];
    }

    return obj;
}

static VALUE bf_include(VALUE self, VALUE key) {
    VALUE skey;
    unsigned long hash;
    int index;
    int i, len, m, k;
    char *ckey;
    struct BloomFilter *bf = bf_ptr(self);

    skey = rb_obj_as_string(key);
    ckey = StringValuePtr(skey);
    len = (int) (RSTRING_LEN(skey)); /* length of the string in bytes */

    m = bf->m;
    k = bf->k;

    hash = (unsigned long) djb2(ckey, len);
    for (i = 0; i <= k - 1; i++) {
        index = (int) ((hash ^ salts[i]) % (unsigned int) (m));

        /* check the bit at the index */
        if (!bucket_check(bf, index)) {
            return Qfalse; /* i.e., it is a new entry ; escape the loop */
        }
    }

    return Qtrue;
}

static VALUE bf_bitmap(VALUE self) {
    struct BloomFilter *bf = bf_ptr(self);

    VALUE str = rb_str_new(0, bf->bytes);
    unsigned char* ptr = (unsigned char *) RSTRING_PTR(str);

    memcpy(ptr, bf->ptr, bf->bytes);

    return str;
}

static VALUE bf_load(VALUE self, VALUE bitmap) {
    struct BloomFilter *bf = bf_ptr(self);
    VALUE bitmap_string = StringValue(bitmap);
    unsigned char* ptr;

    if (RSTRING_LEN(bitmap_string) != bf->bytes) {
        rb_raise(rb_eArgError, "bitmap length must be %d bytes", bf->bytes);
    }

    ptr = (unsigned char *) RSTRING_PTR(bitmap_string);

    memcpy(bf->ptr, ptr, bf->bytes);

    return Qnil;
}

void Init_cbloomfilter(void) {
    cBloomFilter = rb_define_class("CBloomFilter", rb_cObject);
    rb_define_alloc_func(cBloomFilter, bf_alloc);
    rb_define_method(cBloomFilter, "initialize", bf_initialize, -1);
    rb_define_method(cBloomFilter, "m", bf_m, 0);
    rb_define_method(cBloomFilter, "k", bf_k, 0);
    rb_define_method(cBloomFilter, "set_bits", bf_set_bits, 0);
    rb_define_method(cBloomFilter, "add", bf_add, 1);
    rb_define_method(cBloomFilter, "include?", bf_include, 1);
    rb_define_method(cBloomFilter, "clear", bf_clear, 0);
    rb_define_method(cBloomFilter, "merge", bf_merge, 1);
    rb_define_method(cBloomFilter, "&", bf_and, 1);
    rb_define_method(cBloomFilter, "|", bf_or, 1);

    rb_define_method(cBloomFilter, "bitmap", bf_bitmap, 0);
    rb_define_method(cBloomFilter, "load", bf_load, 1);

    /* functions that have not been implemented, yet */
    //  rb_define_method(cBloomFilter, "<=>", bf_cmp, 1);
}
