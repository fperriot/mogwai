#include "ipclib.h"

static
unsigned align_pow2(unsigned sz)
{
    int i;

    for (i = 31; i >= 0; --i)
    {
        unsigned p2;

        if (p2 = (sz & (1ul << i)))
            return p2;
    }

    return 0;
}

shm_buf_t *shm_init(void *p, unsigned sz)
{
    if (sz < sizeof(shm_buf_t) + sizeof(unsigned))
        return 0;
    else
    {
        shm_buf_t *buf = (shm_buf_t *) p;
        buf->mutex = 0;
        buf->sz = align_pow2((sz - sizeof(shm_buf_t)) / sizeof(unsigned));
        buf->top = buf->tail = 0;
        buf->pending = buf->lost = 0;

        return buf;
    }
}
    
static
void p(shm_buf_t *buf)
{
    unsigned *m = &buf->mutex;

    __asm {
        mov     ecx, 1
        mov     edx, m
spin:
        xor     eax, eax
        lock cmpxchg [edx], ecx
        jnz     spin
    }
}

static
void v(shm_buf_t *buf)
{
    buf->mutex = 0;
}

void shm_post(shm_buf_t *buf, shm_msg_t *msg)
{
    unsigned i;

    p(buf);

    if (buf->pending + msg->cnt >= buf->sz)
      { buf->lost++;
        goto end; }

    for (i = 0; i < msg->cnt && i < MAX_MSG_CNT; ++i)
    {
        buf->circ[(buf->tail + i) & (buf->sz - 1)] = msg->arg[i];
    }

    buf->tail += msg->cnt;
    buf->tail &= buf->sz - 1;
    buf->pending += msg->cnt;

end:
    v(buf);
}

int shm_recv(shm_buf_t *buf, shm_msg_t *msg)
{
    int rc = 0;
    unsigned i;

    p(buf);

    if (buf->pending)
    {
        msg->cnt = buf->circ[buf->top];

        if (msg->cnt > MAX_MSG_CNT)
            msg->cnt = MAX_MSG_CNT;

        for (i = 1; i < msg->cnt; ++i)
        {
            msg->arg[i] = buf->circ[(buf->top + i) & (buf->sz - 1)];
        }

        buf->top += msg->cnt;
        buf->top &= buf->sz - 1;
        buf->pending -= msg->cnt;

        rc = 1;
    }

end:
    v(buf);

    return rc;
}

