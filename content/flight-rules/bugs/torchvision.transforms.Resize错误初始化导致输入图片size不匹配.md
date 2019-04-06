---
title: "torchvision.transforms.Resize错误初始化导致输入图片size不匹配"
date: 2019-02-21T21:36:09+08:00
---

## 错误信息

```error
Traceback (most recent call last):
  File "train.py", line 245, in <module>
    train(opt)
  File "train.py", line 237, in train
    train_model(opt, model, data_loaders, dataset_sizes, criterion, optimizer, scheduler, num_epochs=120)
  File "train.py", line 134, in train_model
    for inputs, labels in data_loaders[phase]:
  File "/home/rayhy/pytorch1.0/lib/python3.5/site-packages/torch/utils/data/dataloader.py", line 637, in __next__
    return self._process_next_batch(batch)
  File "/home/rayhy/pytorch1.0/lib/python3.5/site-packages/torch/utils/data/dataloader.py", line 658, in _process_next_batch
    raise batch.exc_type(batch.exc_msg)
RuntimeError: Traceback (most recent call last):
  File "/home/rayhy/pytorch1.0/lib/python3.5/site-packages/torch/utils/data/dataloader.py", line 138, in _worker_loop
    samples = collate_fn([dataset[i] for i in batch_indices])
  File "/home/rayhy/pytorch1.0/lib/python3.5/site-packages/torch/utils/data/dataloader.py", line 232, in default_collate
    return [default_collate(samples) for samples in transposed]
  File "/home/rayhy/pytorch1.0/lib/python3.5/site-packages/torch/utils/data/dataloader.py", line 232, in <listcomp>
    return [default_collate(samples) for samples in transposed]
  File "/home/rayhy/pytorch1.0/lib/python3.5/site-packages/torch/utils/data/dataloader.py", line 209, in default_collate
    return torch.stack(batch, 0, out=out)
RuntimeError: invalid argument 0: Sizes of tensors must match except in dimension 0. Got 342 and 281 in dimension 3 at /pytorch/aten/src/TH/generic/THTensorMoreMath.cpp:1333
```

这个报错信息提供的信息很少，只知道是data_loader出了问题，但这步封装的很厉害，报错堆栈全部都是torch自己的代码，一时想不到哪里出了问题。

## 分析

这种情况当然是先Google，找到一个报错基本一致，但是原因完全不一样的[链接](https://discuss.pytorch.org/t/runtimeerror-invalid-argument-0/17919)。这个链接中有人提示：`Got 3 and 1 in dimension 1`可能原因是输入图片中混合了3通道图片和单通道图片。在楼主把所有的输入图片转成3通道后，确实解决了问题。

再回到我自己的报错，`Got 342 and 281 in dimension 3`。猜测是图片的宽或者高匹配不上了。看一下我代码中的transform：

```python
transform_dict = {"train": [
        transforms.Resize(input_size, interpolation=3),
        transforms.Pad(10),
        transforms.RandomCrop(input_size),
        transforms.RandomHorizontalFlip(),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
    ], "val": [
        transforms.Resize(input_size, interpolation=3),  # Image.BICUBIC
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
    ]}
```

关于尺寸的transform就是`transforms.Resize(input_size, interpolation=3)`了。查看Resize的文档:

> size (sequence or int) – Desired output size. If size is a sequence like (h, w), output size will be matched to this. If size is an int, smaller edge of the image will be matched to this number. i.e, if height > width, then image will be rescaled to (size * height / width, size)

size这个参数既可以是一个数字，又可以是一个tuple，我代码中写的是input_size，按照文档所言，图片处理后的输出尺寸每次都会被重新计算为(input_size*height/width, size)，这样如果输入图片尺寸不一致，输出图片尺寸会不一致。

## 解决方案

更改方法很简单，把`transforms.Resize(input_size, interpolation=3)`改写成`transforms.Resize((input_size,input_size), interpolation=3)`就行了。