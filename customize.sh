# space
ui_print " "

# log
if [ "$BOOTMODE" != true ]; then
  FILE=/sdcard/$MODID\_recovery.log
  ui_print "- Log will be saved at $FILE"
  exec 2>$FILE
  ui_print " "
fi

# optionals
OPTIONALS=/sdcard/optionals.prop
if [ ! -f $OPTIONALS ]; then
  touch $OPTIONALS
fi

# debug
if [ "`grep_prop debug.log $OPTIONALS`" == 1 ]; then
  ui_print "- The install log will contain detailed information"
  set -x
  ui_print " "
fi

# var
LIST32BIT=`getprop ro.product.cpu.abilist32`

# run
. $MODPATH/function.sh

# info
MODVER=`grep_prop version $MODPATH/module.prop`
MODVERCODE=`grep_prop versionCode $MODPATH/module.prop`
ui_print " ID=$MODID"
ui_print " Version=$MODVER"
ui_print " VersionCode=$MODVERCODE"
if [ "$KSU" == true ]; then
  ui_print " KSUVersion=$KSU_VER"
  ui_print " KSUVersionCode=$KSU_VER_CODE"
  ui_print " KSUKernelVersionCode=$KSU_KERNEL_VER_CODE"
  sed -i 's|#k||g' $MODPATH/post-fs-data.sh
else
  ui_print " MagiskVersion=$MAGISK_VER"
  ui_print " MagiskVersionCode=$MAGISK_VER_CODE"
fi
ui_print " "

# sdk
NUM=26
if [ "$API" -lt $NUM ]; then
  ui_print "! Unsupported SDK $API."
  ui_print "  You have to upgrade your Android version"
  ui_print "  at least SDK API $NUM to use this module."
  abort
else
  ui_print "- SDK $API"
  if [ "`grep_prop misound.dolby $OPTIONALS`" != 0 ]; then
    if [ "$API" -lt 28 ]; then
      ui_print "  ! Unsupported Dolby Atmos."
      DOLBY=false
    else
      DOLBY=true
    fi
  else
    DOLBY=false
  fi
  ui_print " "
fi

# miuicore
if [ ! -d /data/adb/modules_update/MiuiCore ]\
&& [ ! -d /data/adb/modules/MiuiCore ]; then
  ui_print "! Miui Core Magisk Module is not installed."
  ui_print "  MiSound app will not be working without"
  ui_print "  Miui Core Magisk Module except you are in Miui ROM!"
  ui_print " "
else
  rm -f /data/adb/modules/MiuiCore/remove
  rm -f /data/adb/modules/MiuiCore/disable
fi

# recovery
mount_partitions_in_recovery

# magisk
magisk_setup

# path
SYSTEM=`realpath $MIRROR/system`
if [ "$BOOTMODE" == true ]; then
  if [ ! -d $MIRROR/vendor ]; then
    mount_vendor_to_mirror
  fi
  if [ ! -d $MIRROR/product ]; then
    mount_product_to_mirror
  fi
  if [ ! -d $MIRROR/system_ext ]; then
    mount_system_ext_to_mirror
  fi
  if [ ! -d $MIRROR/odm ]; then
    mount_odm_to_mirror
  fi
  if [ ! -d $MIRROR/my_product ]; then
    mount_my_product_to_mirror
  fi
fi
VENDOR=`realpath $MIRROR/vendor`
PRODUCT=`realpath $MIRROR/product`
SYSTEM_EXT=`realpath $MIRROR/system_ext`
ODM=`realpath $MIRROR/odm`
MY_PRODUCT=`realpath $MIRROR/my_product`

# .aml.sh
mv -f $MODPATH/aml.sh $MODPATH/.aml.sh

# socket
if [ ! -e /dev/socket/audio_hw_socket ]; then
  ui_print "! Unsupported audio_hw_socket."
  ui_print "  Mi Sound EQ will not be working with this device"
  ui_print "  but you can still use the Dolby Atmos EQ."
  ui_print " "
fi

# function
run_check_function() {
LISTS=`strings $MODPATH/system_dolby/vendor$DIR/$DES | grep ^lib | grep .so`
FILE=`for LIST in $LISTS; do echo $SYSTEM$DIR/$LIST; done`
ui_print "- Checking"
ui_print "$NAME"
ui_print "  function at"
ui_print "$FILE"
ui_print "  Please wait..."
if ! grep -q $NAME $FILE; then
  ui_print "  Function not found."
  ui_print "  Using new $DIR$LIB"
  mv -f $MODPATH/system_support$DIR/$LIB $MODPATH/system$DIR
fi
ui_print " "
}
check_function() {
if [ "$IS64BIT" == true ]; then
  DIR=/lib64
  run_check_function
fi
if [ "$LIST32BIT" ] && [ $DOLBY32 == true ]; then
  DIR=/lib
  run_check_function
fi
}

# bit
if [ "$IS64BIT" == true ]; then
  ui_print "- 64 bit architecture"
  ui_print " "
  # 32 bit
  if [ "$LIST32BIT" ]; then
    ui_print "- 32 bit library support"
  else
    ui_print "- Doesn't support 32 bit library"
    rm -rf $MODPATH/armeabi-v7a $MODPATH/x86\
     $MODPATH/system*/lib $MODPATH/system*/vendor/lib
  fi
  ui_print " "
  # check
  NAME=_ZN7android23sp_report_stack_pointerEv
  if [ $DOLBY == true ]; then
    ui_print "- Activating Dolby Atmos..."
    ui_print " "
    FILE=$VENDOR/lib64/hw/*audio*.so
    ui_print "- Checking"
    ui_print "$NAME"
    ui_print "  function at"
    ui_print "$FILE"
    ui_print "  Please wait..."
    if grep -q $NAME $FILE; then
      DOLBY=true
    else
      ui_print "  ! Function not found."
      ui_print "    Unsupported Dolby Atmos."
      DOLBY=false
    fi
  fi
  if [ $DOLBY == true ] && [ "$LIST32BIT" ]; then
    FILE=$VENDOR/lib/hw/*audio*.so
    ui_print "- Checking"
    ui_print "$NAME"
    ui_print "  function at"
    ui_print "$FILE"
    ui_print "  Please wait..."
    if grep -q $NAME $FILE; then
      DOLBY32=true
    else
      ui_print "  Function not found."
      DOLBY32=false
      rm -rf $MODPATH/system_dolby/lib $MODPATH/system_dolby/vendor/lib
    fi
    ui_print " "
  fi
  # check
  NAME=_ZN7android8hardware23getOrCreateCachedBinderEPNS_4hidl4base4V1_05IBaseE
  DES=vendor.dolby.hardware.dms@2.0.so
  LIB=libhidlbase.so
  if [ $DOLBY == true ]; then
    check_function
  fi
  if [ $DOLBY == true ]; then
    MODNAME2='Mi Sound and Dolby Atmos Redmi K40'
    sed -i "s|$MODNAME|$MODNAME2|g" $MODPATH/module.prop
    MODNAME=$MODNAME2
    sed -i 's|#d||g' $MODPATH/.aml.sh
    sed -i 's|#d||g' $MODPATH/*.sh
    cp -rf $MODPATH/system_dolby/* $MODPATH/system
  fi
else
  ui_print "- 32 bit architecture"
  rm -rf `find $MODPATH -type d -name *64*`
  if [ $DOLBY == true ]; then
    ui_print "  ! Unsupported Dolby Atmos."
    DOLBY=false
  fi
  ui_print " "
fi
rm -rf $MODPATH/system_dolby

# check
FILE=$VENDOR/lib/soundfx/libmisoundfx.so
FILE2=$ODM/lib/soundfx/libmisoundfx.so
FILE3=$VENDOR/lib64/soundfx/libmisoundfx.so
FILE4=$ODM/lib64/soundfx/libmisoundfx.so
if [ -f $FILE ] || [ -f $FILE2 ] || [ -f $FILE3 ]\
|| [ -f $FILE4 ]; then
  ui_print "- Built-in misoundfx is detected."
  rm -f `find $MODPATH/system/vendor -type f -name *misound*`
  ui_print " "
else
  NAME=_ZN7android23sp_report_stack_pointerEv
  if [ "$IS64BIT" == true ]; then
    FILE=$VENDOR/lib64/hw/*audio*.so
    ui_print "- Checking"
    ui_print "$NAME"
    ui_print "  function at"
    ui_print "$FILE"
    ui_print "  Please wait..."
    if grep -q $NAME $FILE; then
      FUNC64=true
    else
      ui_print "  Function not found."
      FUNC64=false
    fi
  else
    FUNC64=false
  fi
  if [ "$LIST32BIT" ]; then
    FILE=$VENDOR/lib/hw/*audio*.so
    ui_print "- Checking"
    ui_print "$NAME"
    ui_print "  function at"
    ui_print "$FILE"
    ui_print "  Please wait..."
    if grep -q $NAME $FILE; then
      FUNC32=true
    else
      ui_print "  Function not found."
      FUNC32=false
    fi
  else
    FUNC32=false
  fi
  if [ $FUNC64 != true ] && [ $FUNC32 != true ]; then
    if [ ! "$LIST32BIT" ]; then
      abort "  ! This ROM doesn't support 32 bit library."
    fi
    ui_print "  Using legacy libraries."
    cp -rf $MODPATH/system_10/* $MODPATH/system
    rm -f $MODPATH/system/vendor/lib64/soundfx/libmisoundfx.so
  elif [ $FUNC64 == true ] && [ $FUNC32 != true ]; then
    rm -f $MODPATH/system/vendor/lib/soundfx/libmisoundfx.so
  elif [ $FUNC64 != true ] && [ $FUNC32 == true ]; then
    rm -f $MODPATH/system/vendor/lib64/soundfx/libmisoundfx.so
  fi
fi
rm -rf $MODPATH/system_10

# sepolicy
FILE=$MODPATH/sepolicy.rule
DES=$MODPATH/sepolicy.pfsd
if [ "`grep_prop sepolicy.sh $OPTIONALS`" == 1 ]\
&& [ -f $FILE ]; then
  mv -f $FILE $DES
fi

# mod ui
if [ "`grep_prop mod.ui $OPTIONALS`" == 1 ]; then
  APP=MiSound
  FILE=/sdcard/$APP.apk
  DIR=`find $MODPATH/system -type d -name $APP`
  ui_print "- Using modified UI apk..."
  if [ -f $FILE ]; then
    cp -f $FILE $DIR
    chmod 0644 $DIR/$APP.apk
    ui_print "  Applied"
  else
    ui_print "  ! There is no $FILE file."
    ui_print "    Please place the apk to your internal storage first"
    ui_print "    and reflash!"
  fi
  ui_print " "
fi

# function
extract_lib() {
for APP in $APPS; do
  FILE=`find $MODPATH/system -type f -name $APP.apk`
  if [ -f `dirname $FILE`/extract ]; then
    rm -f `dirname $FILE`/extract
    ui_print "- Extracting..."
    DIR=`dirname $FILE`/lib/"$ARCH"
    mkdir -p $DIR
    rm -rf $TMPDIR/*
    DES=lib/"$ABI"/*
    unzip -d $TMPDIR -o $FILE $DES
    cp -f $TMPDIR/$DES $DIR
    ui_print " "
  fi
done
}

# extract
APPS="`ls $MODPATH/system/priv-app` `ls $MODPATH/system/app`"
extract_lib

# cleaning
ui_print "- Cleaning..."
if [ $DOLBY == true ]; then
  PKGS=`cat $MODPATH/package-dolby.txt`
  rm -f /data/vendor/dolby/dax_sqlite3.db
else
  PKGS=`cat $MODPATH/package.txt`
fi
if [ "$BOOTMODE" == true ]; then
  for PKG in $PKGS; do
    RES=`pm uninstall $PKG 2>/dev/null`
  done
fi
rm -rf $MODPATH/unused
remove_sepolicy_rule
ui_print " "

# function
conflict() {
for NAME in $NAMES; do
  DIR=/data/adb/modules_update/$NAME
  if [ -f $DIR/uninstall.sh ]; then
    sh $DIR/uninstall.sh
  fi
  rm -rf $DIR
  DIR=/data/adb/modules/$NAME
  rm -f $DIR/update
  touch $DIR/remove
  FILE=/data/adb/modules/$NAME/uninstall.sh
  if [ -f $FILE ]; then
    sh $FILE
    rm -f $FILE
  fi
  rm -rf /metadata/magisk/$NAME
  rm -rf /mnt/vendor/persist/magisk/$NAME
  rm -rf /persist/magisk/$NAME
  rm -rf /data/unencrypted/magisk/$NAME
  rm -rf /cache/magisk/$NAME
  rm -rf /cust/magisk/$NAME
done
}
conflict_disable() {
for NAME in $NAMES; do
  DIR=/data/adb/modules_update/$NAME
  touch $DIR/disable
  DIR=/data/adb/modules/$NAME
  touch $DIR/disable
done
}

# conflict
NAMES=diracmisoundfxRemover
conflict_disable
if [ $DOLBY == true ]; then
  NAMES="dolbyatmos DolbyAudio DolbyAtmos MotoDolby
         dsplus Dolby"
  conflict
  NAMES=SoundEnhancement
  FILE=/data/adb/modules/$NAMES/module.prop
  if grep -q 'Dolby Atmos Xperia' $FILE; then
    conflict
  fi
fi

# function
cleanup() {
if [ -f $DIR/uninstall.sh ]; then
  sh $DIR/uninstall.sh
fi
DIR=/data/adb/modules_update/$MODID
if [ -f $DIR/uninstall.sh ]; then
  sh $DIR/uninstall.sh
fi
}

# cleanup
DIR=/data/adb/modules/$MODID
FILE=$DIR/module.prop
if [ "`grep_prop data.cleanup $OPTIONALS`" == 1 ]; then
  sed -i 's|^data.cleanup=1|data.cleanup=0|g' $OPTIONALS
  ui_print "- Cleaning-up $MODID data..."
  cleanup
  ui_print " "
elif [ -d $DIR ] && ! grep -q "$MODNAME" $FILE; then
  ui_print "- Different version detected"
  ui_print "  Cleaning-up $MODID data..."
  cleanup
  ui_print " "
fi

# function
permissive_2() {
sed -i 's|#2||g' $MODPATH/post-fs-data.sh
}
permissive() {
FILE=/sys/fs/selinux/enforce
SELINUX=`cat $FILE`
if [ "$SELINUX" == 1 ]; then
  if ! setenforce 0; then
    echo 0 > $FILE
  fi
  SELINUX=`cat $FILE`
  if [ "$SELINUX" == 1 ]; then
    ui_print "  Your device can't be turned to Permissive state."
    ui_print "  Using Magisk Permissive mode instead."
    permissive_2
  else
    if ! setenforce 1; then
      echo 1 > $FILE
    fi
    sed -i 's|#1||g' $MODPATH/post-fs-data.sh
  fi
else
  sed -i 's|#1||g' $MODPATH/post-fs-data.sh
fi
}
backup() {
if [ ! -f $FILE.orig ] && [ ! -f $FILE.bak ]; then
  cp -af $FILE $FILE.orig
fi
}
patch_manifest() {
if [ -f $FILE ]; then
  backup
  if [ -f $FILE.orig ] || [ -f $FILE.bak ]; then
    ui_print "- Created"
    ui_print "$FILE.orig"
    ui_print " "
    ui_print "- Patching"
    ui_print "$FILE"
    ui_print "  directly..."
    sed -i '/<manifest/a\
    <hal format="hidl">\
        <name>vendor.dolby.hardware.dms</name>\
        <transport>hwbinder</transport>\
        <version>2.0</version>\
        <interface>\
            <name>IDms</name>\
            <instance>default</instance>\
        </interface>\
        <fqname>@2.0::IDms/default</fqname>\
    </hal>' $FILE
    ui_print " "
  else
    ui_print "- Failed to create"
    ui_print "$FILE.orig"
    ui_print " "
  fi
fi
}
patch_hwservice() {
if [ -f $FILE ]; then
  backup
  if [ -f $FILE.orig ] || [ -f $FILE.bak ]; then
    ui_print "- Created"
    ui_print "$FILE.orig"
    ui_print " "
    ui_print "- Patching"
    ui_print "$FILE"
    ui_print "  directly..."
    sed -i '1i\
vendor.dolby.hardware.dms::IDms u:object_r:hal_dms_hwservice:s0' $FILE
    ui_print " "
  else
    ui_print "- Failed to create"
    ui_print "$FILE.orig"
    ui_print " "
  fi
fi
}
early_init_mount_dir() {
if echo $MAGISK_VER | grep -q delta\
&& [ "`grep_prop dolby.skip.early $OPTIONALS`" != 1 ]; then
  EIM=true
  if "$BOOTMODE"\
  && [ -L $MIRROR/early-mount ]; then
    EIMDIR=`readlink $MIRROR/early-mount`
    [ "${EIMDIR:0:1}" != "/" ] && EIMDIR="$MIRROR/$EIMDIR"
  elif "$BOOTMODE"\
  && [ "$MAGISK_VER_CODE" -ge 26000 ]\
  && [ -d $MAGISKTMP/preinit ]; then
    MOUNT=`mount | grep $MAGISKTMP/preinit`
    BLOCK=`echo $MOUNT | sed 's| on.*||g'`
    DIR=`mount | sed "s|$MOUNT||g" | grep -m 1 $BLOCK`
    EIMDIR=`echo $DIR | sed "s|$BLOCK on ||g" | sed 's| type.*||g'`/early-mount.d
  elif ! $ISENCRYPTED; then
    EIMDIR=/data/adb/early-mount.d
  elif [ -d /data/unencrypted ]\
  && ! grep ' /data ' /proc/mounts | grep -q dm-\
  && grep ' /data ' /proc/mounts | grep -q ext4; then
    EIMDIR=/data/unencrypted/early-mount.d
  elif grep ' /cache ' /proc/mounts | grep -q ext4; then
    EIMDIR=/cache/early-mount.d
  elif grep ' /metadata ' /proc/mounts | grep -q ext4; then
    EIMDIR=/metadata/early-mount.d
  elif grep ' /persist ' /proc/mounts | grep -q ext4; then
    EIMDIR=/persist/early-mount.d
  elif grep ' /mnt/vendor/persist ' /proc/mounts | grep -q ext4; then
    EIMDIR=/mnt/vendor/persist/early-mount.d
  elif grep ' /cust ' /proc/mounts | grep -q ext4; then
    EIMDIR=/cust/early-mount.d
  elif [ "$MAGISK_VER_CODE" -ge 26000 ]\
  && [ -d /data/unencrypted ]\
  && ! grep ' /data ' /proc/mounts | grep -q dm-\
  && grep ' /data ' /proc/mounts | grep -q f2fs; then
    EIMDIR=/data/unencrypted/early-mount.d
  elif [ "$MAGISK_VER_CODE" -ge 26000 ]\
  && grep ' /cache ' /proc/mounts | grep -q f2fs; then
    EIMDIR=/cache/early-mount.d
  elif [ "$MAGISK_VER_CODE" -ge 26000 ]\
  && grep ' /metadata ' /proc/mounts | grep -q f2fs; then
    EIMDIR=/metadata/early-mount.d
  elif [ "$MAGISK_VER_CODE" -ge 26000 ]\
  && grep ' /persist ' /proc/mounts | grep -q f2fs; then
    EIMDIR=/persist/early-mount.d
  elif [ "$MAGISK_VER_CODE" -ge 26000 ]\
  && grep ' /mnt/vendor/persist ' /proc/mounts | grep -q f2fs; then
    EIMDIR=/mnt/vendor/persist/early-mount.d
  elif [ "$MAGISK_VER_CODE" -ge 26000 ]\
  && grep ' /cust ' /proc/mounts | grep -q f2fs; then
    EIMDIR=/cust/early-mount.d
  else
    EIM=false
    ui_print "- Unable to find early init mount directory"
    ui_print " "
  fi
  if [ -d ${EIMDIR%/early-mount.d} ]; then
    mkdir -p $EIMDIR
    ui_print "- Your early init mount directory is"
    ui_print "  $EIMDIR"
    ui_print "  Any file stored to this directory will not be deleted"
    ui_print "  even you have uninstalled this module."
  else
    EIM=false
    ui_print "- Unable to find early init mount directory ${EIMDIR%/early-mount.d}"
  fi
  ui_print " "
else
  EIM=false
fi
}
run_find_file() {
for NAME in $NAMES; do
  FILE=`find $SYSTEM$DIR $SYSTEM_EXT$DIR -type f -name $NAME`
  if [ ! "$FILE" ]; then
    if [ "`grep_prop install.hwlib $OPTIONALS`" == 1 ]; then
      ui_print "- Installing $DIR/$NAME directly to"
      ui_print "$SYSTEM..."
      cp $MODPATH/system_support$DIR/$NAME $SYSTEM$DIR
      DES=$SYSTEM$DIR/$NAME
      if [ -f $MODPATH/system_support$DIR/$NAME ]\
      && [ ! -f $DES ]; then
        ui_print "  ! Installation failed."
        ui_print "    Using $DIR/$NAME systemlessly."
        cp -f $MODPATH/system_support$DIR/$NAME $MODPATH/system$DIR
      fi
    else
      ui_print "! $DIR/$NAME not found."
      ui_print "  Using $DIR/$NAME systemlessly."
      cp -f $MODPATH/system_support$DIR/$NAME $MODPATH/system$DIR
      ui_print "  If this module still doesn't work, type:"
      ui_print "  install.hwlib=1"
      ui_print "  inside $OPTIONALS"
      ui_print "  and reinstall this module"
      ui_print "  to install $DIR/$NAME directly to this ROM."
      ui_print "  DwYOR!"
    fi
    ui_print " "
  fi
done
}
find_file() {
if [ "$IS64BIT" == true ]; then
  DIR=/lib64
  run_find_file
fi
if [ "$LIST32BIT" ]; then
  DIR=/lib
  run_find_file
fi
sed -i 's|^install.hwlib=1|install.hwlib=0|g' $OPTIONALS
}
patch_manifest_eim() {
if [ $EIM == true ]; then
  SRC=$SYSTEM/etc/vintf/manifest.xml
  if [ -f $SRC ]; then
    DIR=$EIMDIR/system/etc/vintf
    DES=$DIR/manifest.xml
    mkdir -p $DIR
    if [ ! -f $DES ]; then
      cp -af $SRC $DIR
    fi
    if ! grep -A2 vendor.dolby.hardware.dms $DES | grep -q 2.0; then
      ui_print "- Patching"
      ui_print "$SRC"
      ui_print "  systemlessly using early init mount..."
      sed -i '/<manifest/a\
    <hal format="hidl">\
        <name>vendor.dolby.hardware.dms</name>\
        <transport>hwbinder</transport>\
        <version>2.0</version>\
        <interface>\
            <name>IDms</name>\
            <instance>default</instance>\
        </interface>\
        <fqname>@2.0::IDms/default</fqname>\
    </hal>' $DES
      ui_print " "
    fi
  else
    EIM=false
  fi
fi
}
patch_hwservice_eim() {
if [ $EIM == true ]; then
  SRC=$SYSTEM/etc/selinux/plat_hwservice_contexts
  if [ -f $SRC ]; then
    DIR=$EIMDIR/system/etc/selinux
    DES=$DIR/plat_hwservice_contexts
    mkdir -p $DIR
    if [ ! -f $DES ]; then
      cp -af $SRC $DIR
    fi
    if ! grep -Eq 'u:object_r:hal_dms_hwservice:s0|u:object_r:default_android_hwservice:s0' $DES; then
      ui_print "- Patching"
      ui_print "$SRC"
      ui_print "  systemlessly using early init mount..."
      sed -i '1i\
vendor.dolby.hardware.dms::IDms u:object_r:hal_dms_hwservice:s0' $DES
      ui_print " "
    fi
  else
    EIM=false
  fi
fi
}

# permissive
if [ "`grep_prop permissive.mode $OPTIONALS`" == 1 ]; then
  ui_print "- Using device Permissive mode."
  rm -f $MODPATH/sepolicy.rule
  permissive
  ui_print " "
elif [ "`grep_prop permissive.mode $OPTIONALS`" == 2 ]; then
  ui_print "- Using Magisk Permissive mode."
  rm -f $MODPATH/sepolicy.rule
  permissive_2
  ui_print " "
fi

# remount
if [ $DOLBY == true ]; then
  remount_rw
fi

# early init mount dir
if [ $DOLBY == true ]; then
  early_init_mount_dir
fi

# check
#chcon -R u:object_r:system_lib_file:s0 $MODPATH/system_support/lib*
#NAMES="libhidltransport.so libhwbinder.so"
#if [ $DOLBY == true ]; then
#  find_file
#fi
rm -rf $MODPATH/system_support

# patch manifest.xml
if [ $DOLBY == true ]; then
  FILE="$MAGISKTMP/mirror/*/etc/vintf/manifest.xml
        $MAGISKTMP/mirror/*/*/etc/vintf/manifest.xml
        /*/etc/vintf/manifest.xml /*/*/etc/vintf/manifest.xml
        $MAGISKTMP/mirror/*/etc/vintf/manifest/*.xml
        $MAGISKTMP/mirror/*/*/etc/vintf/manifest/*.xml
        /*/etc/vintf/manifest/*.xml /*/*/etc/vintf/manifest/*.xml"
  if [ "`grep_prop dolby.skip.vendor $OPTIONALS`" != 1 ]\
  && ! grep -A2 vendor.dolby.hardware.dms $FILE | grep -q 2.0; then
    FILE=$VENDOR/etc/vintf/manifest.xml
    patch_manifest
  fi
  if [ "`grep_prop dolby.skip.system $OPTIONALS`" != 1 ]\
  && ! grep -A2 vendor.dolby.hardware.dms $FILE | grep -q 2.0; then
    FILE=$SYSTEM/etc/vintf/manifest.xml
    patch_manifest
  fi
  if [ "`grep_prop dolby.skip.system_ext $OPTIONALS`" != 1 ]\
  && ! grep -A2 vendor.dolby.hardware.dms $FILE | grep -q 2.0; then
    FILE=$SYSTEM_EXT/etc/vintf/manifest.xml
    patch_manifest
  fi
  if ! grep -A2 vendor.dolby.hardware.dms $FILE | grep -q 2.0; then
    patch_manifest_eim
    if [ $EIM == false ]; then
      ui_print "- Using systemless manifest.xml patch."
      ui_print "  On some ROMs, it causes bugs or even makes bootloop"
      ui_print "  because not allowed to restart hwservicemanager."
      ui_print "  You can fix this by using Magisk Delta."
      ui_print " "
    fi
    FILES="$MAGISKTMP/mirror/*/etc/vintf/manifest.xml
           $MAGISKTMP/mirror/*/*/etc/vintf/manifest.xml
           /*/etc/vintf/manifest.xml /*/*/etc/vintf/manifest.xml"
    restore
  fi
fi

# patch hwservice contexts
if [ $DOLBY == true ]; then
  FILE="$MAGISKTMP/mirror/*/etc/selinux/*_hwservice_contexts
        $MAGISKTMP/mirror/*/*/etc/selinux/*_hwservice_contexts
        /*/etc/selinux/*_hwservice_contexts
        /*/*/etc/selinux/*_hwservice_contexts"
  if [ "`grep_prop dolby.skip.vendor $OPTIONALS`" != 1 ]\
  && ! grep -Eq 'u:object_r:hal_dms_hwservice:s0|u:object_r:default_android_hwservice:s0' $FILE; then
    FILE=$VENDOR/etc/selinux/vendor_hwservice_contexts
    patch_hwservice
  fi
  if [ "`grep_prop dolby.skip.system $OPTIONALS`" != 1 ]\
  && ! grep -Eq 'u:object_r:hal_dms_hwservice:s0|u:object_r:default_android_hwservice:s0' $FILE; then
    FILE=$SYSTEM/etc/selinux/plat_hwservice_contexts
    patch_hwservice
  fi
  if [ "`grep_prop dolby.skip.system_ext $OPTIONALS`" != 1 ]\
   && ! grep -Eq 'u:object_r:hal_dms_hwservice:s0|u:object_r:default_android_hwservice:s0' $FILE; then
    FILE=$SYSTEM_EXT/etc/selinux/system_ext_hwservice_contexts
    patch_hwservice
  fi
  if ! grep -Eq 'u:object_r:hal_dms_hwservice:s0|u:object_r:default_android_hwservice:s0' $FILE; then
    patch_hwservice_eim
    if [ $EIM == false ]; then
      ui_print "! Failed to set hal_dms_hwservice context."
      ui_print " "
    fi
    FILES="$MAGISKTMP/mirror/*/etc/selinux/*_hwservice_contexts
           $MAGISKTMP/mirror/*/*/etc/selinux/*_hwservice_contexts
           /*/etc/selinux/*_hwservice_contexts
           /*/*/etc/selinux/*_hwservice_contexts"
    restore
  fi
fi

# remount
if [ $DOLBY == true ]; then
  remount_ro
fi

# function
hide_oat() {
for APP in $APPS; do
  REPLACE="$REPLACE
  `find $MODPATH/system -type d -name $APP | sed "s|$MODPATH||g"`/oat"
done
}
replace_dir() {
if [ -d $DIR ]; then
  REPLACE="$REPLACE $MODDIR"
fi
}
hide_app() {
for APP in $APPS; do
  DIR=$SYSTEM/app/$APP
  MODDIR=/system/app/$APP
  replace_dir
  DIR=$SYSTEM/priv-app/$APP
  MODDIR=/system/priv-app/$APP
  replace_dir
  DIR=$PRODUCT/app/$APP
  MODDIR=/system/product/app/$APP
  replace_dir
  DIR=$PRODUCT/priv-app/$APP
  MODDIR=/system/product/priv-app/$APP
  replace_dir
  DIR=$MY_PRODUCT/app/$APP
  MODDIR=/system/product/app/$APP
  replace_dir
  DIR=$MY_PRODUCT/priv-app/$APP
  MODDIR=/system/product/priv-app/$APP
  replace_dir
  DIR=$PRODUCT/preinstall/$APP
  MODDIR=/system/product/preinstall/$APP
  replace_dir
  DIR=$SYSTEM_EXT/app/$APP
  MODDIR=/system/system_ext/app/$APP
  replace_dir
  DIR=$SYSTEM_EXT/priv-app/$APP
  MODDIR=/system/system_ext/priv-app/$APP
  replace_dir
  DIR=$VENDOR/app/$APP
  MODDIR=/system/vendor/app/$APP
  replace_dir
  DIR=$VENDOR/euclid/product/app/$APP
  MODDIR=/system/vendor/euclid/product/app/$APP
  replace_dir
done
}

# hide
APPS="`ls $MODPATH/system/priv-app` `ls $MODPATH/system/app`"
hide_oat
APPS=MusicFX
hide_app
if [ $DOLBY == true ]; then
  APPS="DaxUI MotoDolbyDax3 MotoDolbyV3 OPSoundTuner
       DolbyAtmos AudioEffectCenter"
  hide_app
fi

# hide
if [ "`grep_prop hide.parts $OPTIONALS`" == 1 ]; then
  APPS="XiaomiParts ZenfoneParts ZenParts GalaxyParts
       KharaMeParts DeviceParts PocoParts"
  ui_print "- Hides * Parts app"
  hide_app
  ui_print " "
fi

# stream mode
FILE=$MODPATH/.aml.sh
PROP=`grep_prop stream.mode $OPTIONALS`
if echo "$PROP" | grep -q m; then
  ui_print "- Activating music stream..."
  sed -i 's|#m||g' $FILE
  ui_print " "
else
  APPS=AudioFX
  hide_app
fi
if echo "$PROP" | grep -q r; then
  ui_print "- Activating ring stream..."
  sed -i 's|#r||g' $FILE
  ui_print " "
fi
if echo "$PROP" | grep -q a; then
  ui_print "- Activating alarm stream..."
  sed -i 's|#a||g' $FILE
  ui_print " "
fi
if echo "$PROP" | grep -q s; then
  ui_print "- Activating system stream..."
  sed -i 's|#s||g' $FILE
  ui_print " "
fi
if echo "$PROP" | grep -q v; then
  ui_print "- Activating voice_call stream..."
  sed -i 's|#v||g' $FILE
  ui_print " "
fi
if echo "$PROP" | grep -q n; then
  ui_print "- Activating notification stream..."
  sed -i 's|#n||g' $FILE
  ui_print " "
fi
if echo "$PROP" | grep -q b; then
  ui_print "- Activating bluetooth_sco stream..."
  sed -i 's|#b||g' $FILE
  ui_print " "
fi
if echo "$PROP" | grep -q f; then
  ui_print "- Activating dtmf stream..."
  sed -i 's|#f||g' $FILE
  ui_print " "
fi
if echo "$PROP" | grep -q e; then
  ui_print "- Activating enforced_audible stream..."
  sed -i 's|#e||g' $FILE
  ui_print " "
fi
if echo "$PROP" | grep -q y; then
  ui_print "- Activating accessibility stream..."
  sed -i 's|#y||g' $FILE
  ui_print " "
fi
if echo "$PROP" | grep -q t; then
  ui_print "- Activating tts stream..."
  sed -i 's|#t||g' $FILE
  ui_print " "
fi
if echo "$PROP" | grep -q i; then
  ui_print "- Activating assistant stream..."
  sed -i 's|#i||g' $FILE
  ui_print " "
fi
if echo "$PROP" | grep -q c; then
  ui_print "- Activating call_assistant stream..."
  sed -i 's|#c||g' $FILE
  ui_print " "
fi
if echo "$PROP" | grep -q p; then
  ui_print "- Activating patch stream..."
  sed -i 's|#p||g' $FILE
  ui_print " "
fi
if echo "$PROP" | grep -q g; then
  ui_print "- Activating rerouting stream..."
  sed -i 's|#g||g' $FILE
  ui_print " "
fi

# function
dolby_settings() {
FILE=$MODPATH/system/vendor/etc/dolby/dax-default.xml
PROP=`grep_prop dolby.bass $OPTIONALS`
if [ "$PROP" == def ]; then
  ui_print "- Using default settings of bass-enhancer"
elif [ "$PROP" == true ]; then
  ui_print "- Changing all bass-enhancer-enable value to true"
  sed -i 's|bass-enhancer-enable value="false"|bass-enhancer-enable value="true"|g' $FILE
elif [ "$PROP" ] && [ "$PROP" != false ] && [ "$PROP" -gt 0 ]; then
  ui_print "- Changing all bass-enhancer-enable value to true"
  sed -i 's|bass-enhancer-enable value="false"|bass-enhancer-enable value="true"|g' $FILE
  ROWS=`grep bass-enhancer-boost $FILE | sed -e 's|<bass-enhancer-boost value="||g' -e 's|"/>||g'`
  ui_print "- Default bass-enhancer-boost value:"
  ui_print "$ROWS"
  ui_print "- Changing all bass-enhancer-boost value to $PROP"
  for ROW in $ROWS; do
    sed -i "s|bass-enhancer-boost value=\"$ROW\"|bass-enhancer-boost value=\"$PROP\"|g" $FILE
  done
else
  ui_print "- Changing all bass-enhancer-enable value to false"
  sed -i 's|bass-enhancer-enable value="true"|bass-enhancer-enable value="false"|g' $FILE
fi
if [ "`grep_prop dolby.virtualizer $OPTIONALS`" == 1 ]; then
  ui_print "- Changing all virtualizer-enable value to true"
  sed -i 's|virtualizer-enable value="false"|virtualizer-enable value="true"|g' $FILE
elif [ "`grep_prop dolby.virtualizer $OPTIONALS`" == 0 ]; then
  ui_print "- Changing all virtualizer-enable value to false"
  sed -i 's|virtualizer-enable value="true"|virtualizer-enable value="false"|g' $FILE
fi
if [ "`grep_prop dolby.volumeleveler $OPTIONALS`" == def ]; then
  ui_print "- Using default settings of volume-leveler"
elif [ "`grep_prop dolby.volumeleveler $OPTIONALS`" == 1 ]; then
  ui_print "- Changing all volume-leveler-enable value to true"
  sed -i 's|volume-leveler-enable value="false"|volume-leveler-enable value="true"|g' $FILE
else
  ui_print "- Changing all volume-leveler-enable value to false"
  sed -i 's|volume-leveler-enable value="true"|volume-leveler-enable value="false"|g' $FILE
fi
if [ "`grep_prop dolby.deepbass $OPTIONALS`" == 1 ]; then
  ui_print "- Using deeper bass GEQ frequency"
  sed -i 's|frequency="47"|frequency="0"|g' $FILE
  sed -i 's|frequency="141"|frequency="47"|g' $FILE
  sed -i 's|frequency="234"|frequency="141"|g' $FILE
  sed -i 's|frequency="328"|frequency="234"|g' $FILE
  sed -i 's|frequency="469"|frequency="328"|g' $FILE
  sed -i 's|frequency="656"|frequency="469"|g' $FILE
  sed -i 's|frequency="844"|frequency="656"|g' $FILE
  sed -i 's|frequency="1031"|frequency="844"|g' $FILE
  sed -i 's|frequency="1313"|frequency="1031"|g' $FILE
  sed -i 's|frequency="1688"|frequency="1313"|g' $FILE
  sed -i 's|frequency="2250"|frequency="1688"|g' $FILE
  sed -i 's|frequency="3000"|frequency="2250"|g' $FILE
  sed -i 's|frequency="3750"|frequency="3000"|g' $FILE
  sed -i 's|frequency="4688"|frequency="3750"|g' $FILE
  sed -i 's|frequency="5813"|frequency="4688"|g' $FILE
  sed -i 's|frequency="7125"|frequency="5813"|g' $FILE
  sed -i 's|frequency="9000"|frequency="7125"|g' $FILE
  sed -i 's|frequency="11250"|frequency="9000"|g' $FILE
  sed -i 's|frequency="13875"|frequency="11250"|g' $FILE
  sed -i 's|frequency="19688"|frequency="13875"|g' $FILE
fi
ui_print " "
}

# settings
if [ $DOLBY == true ]; then
  dolby_settings
fi

# function
file_check_system() {
for FILE in $FILES; do
  DES=$SYSTEM$FILE
  DES2=$SYSTEM_EXT$FILE
  if [ -f $DES ] || [ -f $DES2 ]; then
    ui_print "- Detected $FILE"
    ui_print " "
    rm -f $MODPATH/system$FILE
  fi
done
}
file_check_vendor() {
for FILE in $FILES; do
  DES=$VENDOR$FILE
  DES2=$ODM$FILE
  if [ -f $DES ] || [ -f $DES2 ]; then
    ui_print "- Detected $FILE"
    ui_print " "
    rm -f $MODPATH/system/vendor$FILE
  fi
done
}

# check
if "$IS64BIT"; then
  FILES=/lib64/libmigui.so
  file_check_system
fi
if [ "LIST32BIT" ]; then
  FILES=/lib/libmigui.so
  file_check_system
fi
if [ $DOLBY == true ]; then
  FILES=/etc/acdbdata/adsp_avs_config.acdb
  file_check_vendor
  if "$IS64BIT"; then
    FILES="/lib64/libdeccfg.so
           /lib64/libstagefrightdolby.so
           /lib64/libstagefright_soft_ddpdec.so
           /lib64/libstagefright_soft_ac4dec.so"
    file_check_vendor
  fi
  if [ "LIST32BIT" ]; then
    FILES="/lib/libdeccfg.so
           /lib/libstagefrightdolby.so
           /lib/libstagefright_soft_ddpdec.so
           /lib/libstagefright_soft_ac4dec.so"
    file_check_vendor
  fi
fi

# harman kardon
FILE=$MODPATH/service.sh
if [ "`grep_prop misound.harmankardon $OPTIONALS`" == 0 ]; then
  ui_print "- Disables Harman Kardon"
  sed -i 's|#h||g' $FILE
  ui_print " "
fi

# audio rotation
FILE=$MODPATH/service.sh
if [ "`grep_prop audio.rotation $OPTIONALS`" == 1 ]; then
  ui_print "- Enables ro.audio.monitorRotation=true"
  sed -i '1i\
resetprop ro.audio.monitorRotation true' $FILE
  ui_print " "
fi

# raw
FILE=$MODPATH/.aml.sh
if [ "`grep_prop disable.raw $OPTIONALS`" == 0 ]; then
  ui_print "- Not disables Ultra Low Latency playback (RAW)"
  ui_print " "
else
  sed -i 's|#u||g' $FILE
fi

# vendor_overlay
DIR=/product/vendor_overlay
if [ "`grep_prop fix.vendor_overlay $OPTIONALS`" == 1 ]\
&& [ $DOLBY == true ] && [ -d $DIR ]; then
  ui_print "- Fixing $DIR mount..."
  cp -rf $DIR/*/* $MODPATH/system/vendor
  ui_print " "
fi

# uninstaller
NAME=DolbyModuleUninstaller.zip
if [ $DOLBY == true ]; then
  cp -f $MODPATH/$NAME /sdcard
  ui_print "- Flash /sdcard/$NAME"
  ui_print "  via recovery only if you got bootloop"
  ui_print " "
fi
rm -f $MODPATH/$NAME

# run
. $MODPATH/copy.sh
. $MODPATH/.aml.sh

# unmount
if [ "$BOOTMODE" == true ] && [ ! "$MAGISKPATH" ]; then
  unmount_mirror
fi














