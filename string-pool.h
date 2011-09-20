#ifndef STRING_POOL_H_
#define STRING_POOL_H_ 1

struct string_pool;

struct string_pool *
string_pool_create (size_t capacity);

const char *
string_pool_get (struct string_pool *map, const char *string);

#endif /* !STRING_POOL_H_ */
