#include <linux/fs.h>
#include <linux/module.h>
#include <linux/miscdevice.h>
#include <linux/uaccess.h>

#define DEVICE_NAME "pwn"
#define BUF_SIZE 64
#define HEAP_SIZE 0x100
static char *heap_buf;

static ssize_t pwn_write(struct file *file,
                         const char __user *user_buf,
                         size_t len,
                         loff_t *off)
{
    char stack_buf[64];

    printk(KERN_INFO "[pwn] write len=%zu\n", len);

    if (copy_from_user(heap_buf, user_buf, len))
        return -EFAULT;

    /* THIS is the vulnerability */
    __memcpy(stack_buf, heap_buf, len);

    return len;
}

static ssize_t pwn_read(struct file *file,
                        char __user *buf,
                        size_t len,
                        loff_t *off)
{
    char stack_buf[64];

    printk(KERN_INFO "pwn_read called\n");
    __memcpy(heap_buf, stack_buf, len);
    if (copy_to_user(buf, heap_buf, len))
        return -EFAULT;

    return len;
}

static struct file_operations fops = {
    .owner = THIS_MODULE,
    .write = pwn_write,
    .read = pwn_read,
};

static struct miscdevice pwn_device = {
    .minor = MISC_DYNAMIC_MINOR,
    .name = DEVICE_NAME,
    .fops = &fops,
    .mode = 0666,
};

static int __init pwn_init(void)
{
    heap_buf = kmalloc(HEAP_SIZE, GFP_KERNEL);
    if (!heap_buf)
        return -ENOMEM;

    return misc_register(&pwn_device);
}

static void __exit pwn_exit(void)
{
    misc_deregister(&pwn_device);
    kfree(heap_buf);
}

module_init(pwn_init);
module_exit(pwn_exit);
MODULE_LICENSE("GPL");
MODULE_AUTHOR("UTKARSH");