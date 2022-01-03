#!/bin/bash

set -euo pipefail

### Configuration

export BIN_DIR="bin"
export CONFIG_DIR="config"
export PLUGINS_DIR="plugins"
export TFLINT_PLUGIN_DIR="$PLUGINS_DIR/tflint"
export TMP_DIR="tmp"

export TERRAFORM_EXE=terraform
export TERRAGRUNT_EXE=terragrunt
export TFLINT_EXE=tflint


### Functions

function generate_configs () {
  TFLINT_AWS_TEMPLATE_CONFIG="$SRC_DIR/templates/tflint/aws/.tflint.hcl"
  cat $TFLINT_AWS_TEMPLATE_CONFIG | sed s/X.X.X/"$TFLINT_AWS_VERSION"/g > $CONFIG_DIR/.tflint.hcl
}

function specify_arch () {
  CPU_TYPE=$(uname -m)

  if [ "$CPU_TYPE" == "x86_64" ]; then
    ARCH="amd64"
  elif [ "$CPU_TYPE" == "arm64" ]; then
    ARCH="arm64"
  else
    ARCH="386"
  fi
  export ARCH
}

function specify_os () {
  OS_ID="$(uname -a)"
  MACOS_ALIAS=Darwin
  if [[ $OS_ID == *"$MACOS_ALIAS"* ]]; then
    export OS=darwin
  else
    export OS=linux
  fi
}

function specify_download_urls () {
  export TERRAFORM_FILE=terraform_"$TERRAFORM_VERSION"_"$OS"_"$ARCH"
  TERRAFORM_URL="https://releases.hashicorp.com/terraform/$TERRAFORM_VERSION/$TERRAFORM_FILE.zip"
  export TERRAFORM_URL

  export TERRAGRUNT_FILE=terragrunt_"$OS"_"$ARCH"
  TERRAGRUNT_URL="https://github.com/gruntwork-io/terragrunt/releases/download/v$TERRAGRUNT_VERSION/$TERRAGRUNT_FILE"
  export TERRAGRUNT_URL

  export TFLINT_FILE=tflint_"$OS"_"$ARCH.zip"
  TFLINT_URL="https://github.com/terraform-linters/tflint/releases/download/v$TFLINT_VERSION/$TFLINT_FILE"
  export TFLINT_URL
}

function specify_versions () {
  TERRAFORM_VERSION=$(jq -r .config.terraform.version "$SRC_DIR/package.json")
  export TERRAFORM_VERSION

  TERRAGRUNT_VERSION=$(jq -r .config.terragrunt.version "$SRC_DIR/package.json")
  export TERRAGRUNT_VERSION

  TFLINT_VERSION=$(jq -r .config.tflint.version "$SRC_DIR/package.json")
  export TFLINT_VERSION

  TFLINT_AWS_VERSION=$(jq -r '.config.tflint.rulesets["ruleset-aws"]' "$SRC_DIR/package.json")
  export TFLINT_AWS_VERSION
}

### Main

if [ ! "${1:-}" ]; then 
  echo "Specify a subcommand."
  exit 1
fi

if [ "${2:-}" ]; then 
  SRC_DIR="$2"
else 
  SRC_DIR="$(pwd)"
fi

export SRC_DIR

case $1 in
  info)
    specify_arch
    specify_os
    specify_versions
    specify_download_urls
    echo "Detected: "
    echo "- CPU architecture: $ARCH"
    echo "- Operating system: $OS"
    echo "Configuration: "
    echo "- Terraform version: $TERRAFORM_VERSION"
    echo "- Terragrunt version: $TERRAGRUNT_VERSION"
    echo "- TFLint version: $TFLINT_VERSION"
    echo "- TFLint AWS ruleset version: $TFLINT_AWS_VERSION"
    echo "- Terraform download URL: $TERRAFORM_URL" 
    echo "- Terragrunt download URL: $TERRAGRUNT_URL" 
    echo "- TFLint download URL: $TFLINT_URL" 
    echo "Installed in project: " 
    ./"$BIN_DIR"/"$TERRAFORM_EXE" version
    ./"$BIN_DIR"/"$TERRAGRUNT_EXE" --version
    ./"$BIN_DIR"/"$TFLINT_EXE" --version
    find $TFLINT_PLUGIN_DIR
  ;;
  clean)
    [ -d $BIN_DIR ] && rm -r $BIN_DIR
    [ -d $CONFIG_DIR ] && rm -r $CONFIG_DIR 
    [ -d $PLUGINS_DIR ] && rm -r $PLUGINS_DIR
    [ -d $TMP_DIR ] && rm -r $TMP_DIR 
  ;;
  configure)
    generate_configs
  ;;
  setup)
    specify_arch
    specify_os
    specify_versions
    specify_download_urls
    [ -d "$BIN_DIR" ] || mkdir "$BIN_DIR"
    [ -d "$CONFIG_DIR" ] || mkdir "$CONFIG_DIR"
    [ -d "$PLUGINS_DIR" ] || mkdir "$PLUGINS_DIR"
    [ -d "$TMP_DIR" ] || mkdir "$TMP_DIR"

    # Terraform
    if [ ! -x "$BIN_DIR/$TERRAFORM_EXE" ]; then 
      curl -L "$TERRAFORM_URL" > $TMP_DIR/$TERRAFORM_EXE.zip
      unzip $TMP_DIR/$TERRAFORM_EXE.zip -d $TMP_DIR
      mv $TMP_DIR/$TERRAFORM_EXE $BIN_DIR/$TERRAFORM_EXE
      chmod +x "$BIN_DIR"/"$TERRAFORM_EXE"
    fi

    # Terragrunt
    if [ ! -x "$BIN_DIR/$TERRAGRUNT_EXE" ]; then 
      curl -L "$TERRAGRUNT_URL" > $BIN_DIR/$TERRAGRUNT_EXE 
      chmod +x "$BIN_DIR"/"$TERRAGRUNT_EXE"
    fi

    # TFLint
    if [ ! -x "$BIN_DIR/$TFLINT_EXE" ]; then 
      curl -L "$TFLINT_URL" > $TMP_DIR/$TFLINT_EXE.zip
      unzip $TMP_DIR/$TFLINT_EXE.zip -d $TMP_DIR
      mv $TMP_DIR/$TFLINT_EXE $BIN_DIR/$TFLINT_EXE
      chmod +x "$BIN_DIR"/"$TFLINT_EXE"
    fi

    generate_configs

    if [ ! -d "$TFLINT_PLUGIN_DIR" ]; then 
      mkdir "$TFLINT_PLUGIN_DIR"
      "$BIN_DIR"/"$TFLINT_EXE" --init -c config/.tflint.hcl
    fi

  ;;
  *)
    echo "$1 is not a valid command"
  ;;
esac
