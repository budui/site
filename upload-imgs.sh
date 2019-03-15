#!/bin/bash

# upload local images to COS.

upload()
{
    localpath=$1
    # "./content/blog/test/test.jpg" -> "img/blog/test/test.jpg"
    uploadpath="img/"${localpath/.\/content\//}
    coscmd upload -s -H '{"Cache-Control":"max-age=2592000"}' "$localpath" "$uploadpath"
}

# upload_all_images are used to upload all images in project to COS.
upload_all_images()
{
# export shell function `upload` to subshell
export -f upload
find ./content -regextype posix-extended -regex ".*\.(jpg|png|gif|bmp)" -exec bash -c 'upload "{}"' \;
}

# upload_all_images are used to upload untracked and modified images in project to COS.
upload_needed_images()
{
    filename=$1
    case "$filename" in
    *.jpg | *.png | *.gif | *.bmp)
        upload "./"$filename
        ;;
    *)
        ;;
    esac
}

if [ -f ./config.toml ]; then
    export -f upload_needed_images
    export -f upload
    # https://stackoverflow.com/questions/11003418/calling-shell-functions-with-xargs
    # The underscore (_) provides a place holder for argv[0] ($0) and almost anything could be used there. 
    git ls-files -z -mo --exclude-standard | xargs -0 -n 1 bash -c 'upload_needed_images "$@"' _
else
    echo "EROOR！ 必须在Project根目录下运行本文件"
fi