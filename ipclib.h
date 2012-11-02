#pragma once

#define MAX_MSG_CNT 10

typedef struct _shm_msg {
    union {
        unsigned cnt;
        unsigned arg[MAX_MSG_CNT];
    };
} shm_msg_t;

typedef struct _shm_buf {
    unsigned mutex;
    unsigned sz;            /* power of two */
    unsigned top, tail;     /* within 0..sz-1 */
    unsigned pending, lost;
    unsigned circ[1];
} shm_buf_t;

shm_buf_t *shm_init(void *p, unsigned sz);
void shm_post(shm_buf_t *buf, shm_msg_t *msg);
int shm_recv(shm_buf_t *buf, shm_msg_t *msg);

