# -*- mode: shell-script; -*-
#
# Copyright (C) 2013 Xavier Garrido
#
# Author: garrido@lal.in2p3.fr
# Keywords: snailware, supernemo
# Requirements: pkgtools
# Status: not intended to be distributed yet

# Add completion
fpath=(${ADOTDIR}/bundles/xgarrido/zsh-aggregator/completions $fpath)

# Aggregator bundles
typeset -ga __aggregator_bundles
__aggregator_bundles=(cadfael bayeux falaise)
typeset -g __aggregator_use_make=false

function aggregator ()
{
    pkgtools::default_values
    pkgtools::at_function_enter aggregator

    local mode
    local append_list_of_options_arg
    local append_list_of_components_arg
    local with_test=false
    local with_warning=true
    local with_doc=false
    local use_clang=false
    local nproc=0

    while [ -n "$1" ]; do
        local token="$1"
        if [ "${token[0,1]}" = "-" ]; then
	    local opt=${token}
            append_list_of_options_arg+="${opt} "
	    if [ "${opt}" = "-h" -o "${opt}" = "--help" ]; then
                return 0
	    elif [ "${opt}" = "-d" -o "${opt}" = "--debug" ]; then
	        pkgtools::msg_using_debug
	    elif [ "${opt}" = "-D" -o "${opt}" = "--devel" ]; then
	        pkgtools::msg_using_devel
	    elif [ "${opt}" = "-v" -o "${opt}" = "--verbose" ]; then
	        pkgtools::msg_using_verbose
	    elif [ "${opt}" = "-W" -o "${opt}" = "--no-warning" ]; then
	        pkgtools::msg_not_using_warning
	    elif [ "${opt}" = "-q" -o "${opt}" = "--quiet" ]; then
	        pkgtools::msg_using_quiet
	        export PKGTOOLS_MSG_QUIET=1
	    elif [ "${opt}" = "-i" -o "${opt}" = "--interactive" ]; then
	        pkgtools::ui_interactive
	    elif [ "${opt}" = "-b" -o "${opt}" = "--batch" ]; then
	        pkgtools::ui_batch
	    elif [ "${opt}" = "-n" -o "${opt}" = "--number-of-processor" ]; then
	        shift 1
                nproc=$1
	    elif [ "${opt}" = "--gui" ]; then
	        pkgtools::ui_using_gui
            elif [ "${opt}" = "--with-test" ]; then
	        with_test=true
            elif [ "${opt}" = "--without-test" ]; then
	        with_test=false
            elif [ "${opt}" = "--with-warning" ]; then
	        with_warning=true
            elif [ "${opt}" = "--without-warning" ]; then
	        with_warning=false
            elif [ "${opt}" = "--with-doc" ]; then
	        with_doc=true
            elif [ "${opt}" = "--without-doc" ]; then
	        with_doc=false
            elif [ "${opt}" = "--use-make" ]; then
                __aggregator_use_make=true
            elif [ "${opt}" = "--use-ninja" ]; then
                __aggregator_use_make=false
            elif [ "${opt}" = "--use-clang" ]; then
                use_clang=true
            elif [ "${opt}" = "--use-env" ]; then
                shift 1
                __aggregator_use_env="$1"
            fi
        else
            if [ "${token}" = "environment" ]; then
                mode="environment"
            elif [ "${token}" = "configure" ]; then
                mode="configure"
            elif [ "${token}" = "build" ]; then
                mode="build"
            elif [ "${token}" = "install" ]; then
                mode="install"
            elif [ "${token}" = "reinstall" ]; then
                mode="reinstall"
            elif [ "${token}" = "reset" ]; then
                mode="reset"
            elif [ "${token}" = "setup" ]; then
                mode="setup"
            elif [ "${token}" = "unsetup" ]; then
                mode="unsetup"
            elif [ "${token}" = "test" ]; then
                mode="test"
            elif [ "${token}" = "checkout" ]; then
                mode="checkout"
            elif [ "${token}" = "dump" ]; then
                mode="dump"
            elif [ "${token}" = "update" ]; then
                mode="update"
            elif [ "${token}" = "goto" ]; then
                mode="goto"
            else
	        arg=${token}
	        if [ "x${arg}" != "x" ]; then
	            append_list_of_components_arg+="${arg} "
	        fi
            fi
        fi
        shift 1
    done

    pkgtools::msg_devel "mode=${mode}"
    pkgtools::msg_devel "append_list_of_components_arg=${append_list_of_components_arg}"
    pkgtools::msg_devel "append_list_of_options_arg=${append_list_of_options_arg}"

    # Remove last space
    append_list_of_components_arg=${append_list_of_components_arg%?}
    append_list_of_options_arg=${append_list_of_options_arg%?}

    # Setting environment
    if [ ${mode} = environment ]; then
        __aggregator_environment
        pkgtools::at_function_exit
        return 0
    else
        if [ ! -n "${AGGREGATOR_SETUP_DONE}" ];then
            pkgtools::msg_warning "Setting default environment"
            __aggregator_environment
        fi
    fi

    # Lookup
    for icompo in ${=append_list_of_components_arg}
    do
        if [ ${icompo} = all ]; then
            aggregator ${append_list_of_options_arg} ${mode} ${__aggregator_bundles}
            continue
        fi

        if [[ ${__aggregator_bundles[(i)${icompo}]} -gt ${#__aggregator_bundles} ]]; then
            pkgtools::msg_error "Aggregator '${icompo}' does not exist!"
            pkgtools::at_function_exit
            return 1
        fi

        # Set aggregator
        __aggregator_set_${icompo}

        pkgtools::msg_devel "repository=${aggregator_repo_dir}"
        pkgtools::msg_devel "build=${aggregator_build_dir}"
        pkgtools::msg_devel "install=${aggregator_install_dir}"

        # Look for the corresponding directory
        local is_found=false
        pushd ${aggregator_repo_dir} > /dev/null 2>&1
        if $(pkgtools::last_command_succeeds); then
            is_found=true
        fi

        if ! ${is_found}; then
            pkgtools::msg_error "Repository of '${icompo}' does not exist!"
            continue
        elif [ ${mode} = goto ]; then
            pkgtools::at_function_exit
            return 0
        fi
        unset is_found

        case ${mode} in
            checkout)
                pkgtools::msg_notice "Getting '${icompo}' aggregator"
                __aggregator_get
                if $(pkgtools::last_command_fails); then
                    pkgtools::msg_error "Getting '${icompo}' aggregator fails !"
                    break
                fi
                ;;
            update)
                pkgtools::msg_notice "Updating '${icompo}' aggregator"
                __aggregator_update
                if $(pkgtools::last_command_fails); then
                    pkgtools::msg_error "Updating '${icompo}' aggregator fails !"
                    break
                fi
                ;;
            setup)
                pkgtools::msg_notice "Sourcing '${icompo}' aggregator"
                __aggregator_setup
                if $(pkgtools::last_command_fails); then
                    pkgtools::msg_error "Sourcing '${icompo}' aggregator fails !"
                    break
                fi
                ;;
            unsetup)
                pkgtools::msg_notice "Un-Sourcing '${icompo}' aggregator"
                __aggregator_unsetup
                if $(pkgtools::last_command_fails); then
                    pkgtools::msg_error "Un-Sourcing '${icompo}' aggregator fails !"
                    break
                fi
                ;;
            configure)
                pkgtools::msg_notice "Configuring '${icompo}' aggregator"
                __aggregator_configure
                if $(pkgtools::last_command_fails); then
                    pkgtools::msg_error "Configuring '${icompo}' aggregator fails !"
                    break
                fi
                ;;
            build)
                pkgtools::msg_notice "Building '${icompo}' aggregator"
                __aggregator_build
                if $(pkgtools::last_command_fails); then
                    pkgtools::msg_error "Building '${icompo}' aggregator fails !"
                    break
                fi
                ;;
            install)
                pkgtools::msg_notice "Installing '${icompo}' aggregator"
                __aggregator_build install
                if $(pkgtools::last_command_fails); then
                    pkgtools::msg_error "Installing '${icompo}' aggregator fails !"
                    break
                fi
                ;;
            dump)
                pkgtools::msg_notice "Dumping '${icompo}' aggregator"
                __aggregator_dump
                if $(pkgtools::last_command_fails); then
                    pkgtools::msg_error "Dumping '${icompo}' aggregator fails !"
                    break
                fi
                ;;
            reset)
                pkgtools::msg_notice "Reseting '${icompo}' aggregator"
                __aggregator_unsetup
                __aggregator_remove
                if $(pkgtools::last_command_fails); then
                    pkgtools::msg_error "Reseting '${icompo}' aggregator fails !"
                    break
                fi
                ;;
            reinstall)
                pkgtools::msg_notice "Reinstalling '${icompo}' aggregator"
                aggregator ${append_list_of_options_arg} reset     ${icompo}
                aggregator ${append_list_of_options_arg} configure ${icompo}
                aggregator ${append_list_of_options_arg} install   ${icompo}
                aggregator ${append_list_of_options_arg} setup     ${icompo}
                ;;
            test)
                pkgtools::msg_notice "Testing '${icompo}' aggregator"
                __aggregator_test
                if $(pkgtools::last_command_fails); then
                    pkgtools::msg_error "Testing '${icompo}' aggregator fails !"
                    break
                fi
                ;;
        esac

        popd > /dev/null 2>&1
    done

    unset aggregator_install_dir  aggregator_options      aggregator_git_path
    unset aggregator_base_dir     aggregator_logfile      aggregator_repo_dir
    unset aggregator_build_dir    aggregator_name
    pkgtools::default_values
    pkgtools::at_function_exit
    return 0

}

function __aggregator_environment ()
{
    pkgtools::at_function_enter __aggregator_environment

    if [ -n "${AGGREGATOR_SETUP_DONE}" ]; then
        pkgtools::at_function_exit
        return 0
    fi
    export AGGREGATOR_SETUP_DONE=1

    # Take care of running machine
    case "${HOSTNAME}" in
        garrido-laptop)
            nemo_base_dir_tmp="/home/${USER}/Workdir/NEMO"
            nemo_pro_dir_tmp="${nemo_base_dir_tmp}/supernemo/snware"
            ;;
        pc-91089)
            nemo_base_dir_tmp="/data/workdir/nemo/"
            nemo_pro_dir_tmp="${nemo_base_dir_tmp}/supernemo/snware"
            ;;
        ccige*|ccage*|cca*)
            nemo_base_dir_tmp="/sps/nemo/scratch/${USER}/workdir"
            nemo_pro_dir_tmp="${nemo_base_dir_tmp}/supernemo/snware"
            ;;
        *.lal.in2p3.fr)
            nemo_base_dir_tmp="/exp/nemo/${USER}/workdir"
            nemo_pro_dir_tmp="${nemo_base_dir_tmp}/supernemo/snware"
            ;;
        girardcarillo-Latitude-7380)
            nemo_base_dir_tmp="/home/${USER}/Workdir"
            nemo_pro_dir_tmp="${nemo_base_dir_tmp}/snware"
    esac

    if env | grep -q "^SNAILWARE_BASE_DIR="; then
        pkgtools::set_variable SNAILWARE_PRO_DIR "$SNAILWARE_BASE_DIR/snware"
    else
        # Export only if it is not already exported
        pkgtools::set_variable SNAILWARE_BASE_DIR "${nemo_base_dir_tmp}"
        pkgtools::set_variable SNAILWARE_PRO_DIR  "${nemo_pro_dir_tmp}"
    fi

    pkgtools::at_function_exit
    return 0
}

function __aggregator_setup ()
{
    pkgtools::at_function_enter __aggregator_setup

    pkgtools::add_path_to_PATH ${aggregator_install_dir}/bin

    pkgtools::at_function_exit
    return 0
}

function __aggregator_unsetup ()
{
    pkgtools::at_function_enter __aggregator_unsetup

    pkgtools::remove_path_to_PATH ${aggregator_install_dir}/bin

    pkgtools::at_function_exit
    return 0
}

function __aggregator_set ()
{
    pkgtools::at_function_enter __aggregator_set

    __aggregator_environment

    if [ ! -d /tmp/${USER} ]; then
        mkdir -p /tmp/${USER}
    fi
    aggregator_logfile=/tmp/${USER}/${aggregator_name}.log
    aggregator_base_dir=${SNAILWARE_PRO_DIR}/${aggregator_name}
    aggregator_repo_dir=${aggregator_base_dir}/repo
    aggregator_build_dir=${aggregator_base_dir}/build
    aggregator_install_dir=${aggregator_base_dir}/install

    if [ "${__aggregator_use_env}" != "" ]; then
        pkgtools::msg_notice "Using ${__aggregator_use_env} version"
        (
            cd ${aggregator_base_dir}
            if [[ -L "${aggregator_build_dir}" && -d "${aggregator_build_dir}" ]]; then
                rm ${aggregator_build_dir}
                ln -sf build_${__aggregator_use_env} build
            fi
            if [[ -L "${aggregator_install_dir}" && -d "${aggregator_install_dir}" ]]; then
                rm ${aggregator_install_dir}
                ln -sf install_${__aggregator_use_env} install
            fi
        )
        aggregator_build_dir+="_${__aggregator_use_env}"
        aggregator_install_dir+="_${__aggregator_use_env}"
        __aggregator_use_env=
    fi

    pkgtools::msg_devel "build=${aggregator_build_dir}"
    pkgtools::msg_devel "install=${aggregator_install_dir}"


    if [ ! -d ${aggregator_build_dir} ]; then
        mkdir -p ${aggregator_build_dir}
    fi

    if [ ! -d ${aggregator_install_dir} ]; then
        mkdir -p ${aggregator_install_dir}
    fi

    if [ ! -d  ${aggregator_repo_dir} ]; then
        pkgtools::msg_warning "${aggregator_repo_dir} directory does not exist ! Create it."
        mkdir -p ${aggregator_repo_dir}
    fi

    if ! ${__aggregator_use_make}; then
        if ! $(pkgtools::has_binary ninja); then
            pkgtools::msg_warning "Ninja binary has not been found !"
            __aggregator_use_make=true
        fi
    fi

    pkgtools::at_function_exit
    return 0
}

function __aggregator_get ()
{
    pkgtools::at_function_enter __aggregator_get

    if $(pkgtools::has_binary git); then
        pkgtools::msg_debug "Machine has git support"
        git clone ${aggregator_git_path} .
        if $(pkgtools::last_command_fails); then
            pkgtools::msg_error "Cloning out fails!"
            pkgtools::at_function_exit
            return 1
        fi
    else
        pkgtools::msg_warning "Machine has no git installed"
        pkgtools::at_function_exit
        return 1
    fi

    pkgtools::at_function_exit
    return 0
}

function __aggregator_update ()
{
    pkgtools::at_function_enter __aggregator_update

    if $(pkgtools::has_binary git); then
        pkgtools::msg_debug "Machine has git support"
        git pull
        if $(pkgtools::last_command_fails); then
            pkgtools::msg_error "Updating fails!"
            pkgtools::at_function_exit
            return 1
        fi
    else
        pkgtools::msg_warning "Machine has no git installed"
        pkgtools::at_function_exit
        return 1
    fi

    pkgtools::at_function_exit
    return 0
}

function __aggregator_configure ()
{
    pkgtools::at_function_enter __aggregator_configure

    if ! ${__aggregator_use_make}; then
        aggregator_options+="-G Ninja -DCMAKE_MAKE_PROGRAM=$(pkgtools::get_binary_path ninja)"
    fi

    pkgtools::msg_devel "aggregator options=${aggregator_options}"

    cd ${aggregator_build_dir}
    cmake                             \
        $(echo ${aggregator_options}) \
        ${aggregator_repo_dir}
    if $(pkgtools::last_command_fails); then
        pkgtools::msg_error "Configuration fails!"
        pkgtools::at_function_exit
        return 1
    fi

    pkgtools::at_function_exit
    return 0
}

function __aggregator_build ()
{
    pkgtools::at_function_enter __aggregator_build

    pkgtools::msg_devel "use make=${__aggregator_use_make}"
    cd ${aggregator_build_dir}

    # Cadfael has no install build command
    local build_options=$1

    if ${__aggregator_use_make}; then
        if [ ${aggregator_name} = cadfael ]; then
            make
        else
            if [ ${nproc} -eq 0 ]; then
                make -j$(nproc) ${build_options}
            else
                make -j${nproc} ${build_options}
            fi
        fi
        if $(pkgtools::last_command_fails); then
            pkgtools::msg_error "Installation fails!"
            pkgtools::at_function_exit
            return 1
        fi
    else
        ninja ${build_options}
        if $(pkgtools::last_command_fails); then
            pkgtools::msg_error "Installation fails!"
            pkgtools::at_function_exit
            return 1
        fi
    fi

    pkgtools::at_function_exit
    return 0
}

function __aggregator_test ()
{
    pkgtools::at_function_enter __aggregator_test

    pkgtools::msg_devel "aggregator build dir=${aggregator_build_dir}"
    cd ${aggregator_build_dir}

    if ${__aggregator_use_make}; then
        make test
        if $(pkgtools::last_command_fails); then
            pkgtools::msg_error "Test fails!"
            pkgtools::at_function_exit
            return 1
        fi
    else
        ninja test
        if $(pkgtools::last_command_fails); then
            pkgtools::msg_error "Test fails!"
            pkgtools::at_function_exit
            return 1
        fi
    fi

    pkgtools::at_function_exit
    return 0
}

function __aggregator_remove ()
{
    pkgtools::at_function_enter __aggregator_remove

    rm -rf ${aggregator_install_dir}
    rm -rf ${aggregator_build_dir}

    pkgtools::at_function_exit
    return 0
}

function __aggregator_dump ()
{
    pkgtools::at_function_enter __aggregator_dump

    pkgtools::msg_notice "Dump aggregator"
    pkgtools::msg_notice " |- name           : ${aggregator_name}"
    pkgtools::msg_notice " |- repository     : ${aggregator_git_path}"
    pkgtools::msg_notice " |- options        : $(echo ${aggregator_options} | sed -e 's/\s\+/\n/g' | sed -e '/^\s*$/d')"
    pkgtools::msg_notice " |- config version : ${aggregator_config_version}"
    pkgtools::msg_notice " |- install dir.   : ${aggregator_install_dir}"
    pkgtools::msg_notice " \`- build dir.    : ${aggregator_build_dir}"

    pkgtools::at_function_exit
    return 0
}

function __aggregator_set_compiler ()
{
    pkgtools::at_function_enter __aggregator_set_compiler
    local cxx
    local cc
    if [[ ${aggregator_name} != cadfael ]]; then
        if $(pkgtools::has_binary ccache); then
            cxx="${cxx}ccache "
            cc="${cc}ccache "
        fi
    fi
    if ${use_clang}; then
        if $(pkgtools::has_binary clang); then
            pkgtools::msg_debug "Using clang compiler"
            cxx="${cxx}clang++ -fcolor-diagnostics -Qunused-arguments -D__extern_always_inline=inline"
            cc="${cc}clang -fcolor-diagnostics -Qunused-arguments -D__extern_always_inline=inline"
        else
            pkgtools::msg_error "Clang compiler is not installed !"
            pkgtools::at_function_exit
            return 1
        fi
    else
        if $(pkgtools::has_binary g++); then
            pkgtools::msg_debug "Using GNU compiler"
            gcc_version=$(g++ --version | head -1 | awk '{print $3}')
            if [[ ${gcc_version} > 4.9 ]]; then
                cxx="${cxx}g++ -Wno-deprecated-declarations -fdiagnostics-color=always -Wno-unused-local-typedefs -ftemplate-backtrace-limit=0 -Wno-noexcept-type"
                cc="${cc}gcc -fdiagnostics-color=always -Wno-unused-local-typedefs"
            else
                cxx="${cxx}g++"
                cc="${cc}gcc"
            fi
        else
            pkgtools::msg_error "GNU compiler is not installed !"
            pkgtools::at_function_exit
            return 1
        fi
    fi
    pkgtools::msg_devel "cxx=$cxx"
    pkgtools::msg_devel "cc=$cc"

    export CXX=$cxx
    export CC=$cc
    pkgtools::at_function_exit
    return 0
}

function __aggregator_set_cadfael
{
    pkgtools::at_function_enter __aggregator_set_cadfael

    aggregator_name="cadfael"
    aggregator_install_dir=$SNAILWARE_PRO_DIR/cadfaelbrew

    pkgtools::at_function_exit
    return 0
}

function __aggregator_set_bayeux
{
    pkgtools::at_function_enter __aggregator_set_bayeux

    # Retrieve Cadfael information
    __aggregator_set_cadfael
    local cadfael_install_dir=${aggregator_install_dir}
    pkgtools::msg_devel "cadfael_install_dir=${cadfael_install_dir}"

    aggregator_name="bayeux"
    aggregator_git_path="git@github.com:BxCppDev/Bayeux.git"
    __aggregator_set
    aggregator_options="                                 \
        -DCMAKE_BUILD_TYPE:STRING=Release                \
        -DCMAKE_INSTALL_PREFIX=${aggregator_install_dir} \
        -DCMAKE_PREFIX_PATH=${cadfael_install_dir}       \
        -DBAYEUX_CXX_STANDARD=14
    "
    if ${with_warning}; then
        aggregator_options+="-DBAYEUX_COMPILER_ERROR_ON_WARNING=ON "
    else
        aggregator_options+="-DBAYEUX_COMPILER_ERROR_ON_WARNING=OFF "
    fi

    if ${with_doc}; then
        aggregator_options+="-DBAYEUX_WITH_DOCS=ON "
    else
        aggregator_options+="-DBAYEUX_WITH_DOCS=OFF "
    fi

    if ${with_test}; then
        aggregator_options+="-DBAYEUX_ENABLE_TESTING=ON "
    else
        aggregator_options+="-DBAYEUX_ENABLE_TESTING=OFF "
    fi

    __aggregator_set_compiler

    pkgtools::at_function_exit
    return 0
}

function __aggregator_set_falaise
{
    pkgtools::at_function_enter __aggregator_set_falaise

    # Retrieve Cadfael information
    __aggregator_set_cadfael
    local cadfael_install_dir=${aggregator_install_dir}
    pkgtools::msg_devel "cadfael_install_dir=${cadfael_install_dir}"
    __aggregator_set_bayeux
    local bayeux_install_dir=${aggregator_install_dir}
    pkgtools::msg_devel "bayeux_install_dir=${bayeux_install_dir}"

    aggregator_name="falaise"
    aggregator_git_path="git@github.com:SuperNEMO-DBD-France/Falaise.git"
    __aggregator_set
    aggregator_options="                                                 \
        -DCMAKE_BUILD_TYPE:STRING=Release                                \
        -DCMAKE_INSTALL_PREFIX=${aggregator_install_dir}                 \
        -DCMAKE_PREFIX_PATH=${cadfael_install_dir};${bayeux_install_dir} \
        -DFALAISE_WITH_DEVELOPER_TOOLS=ON                                \
        -DFALAISE_CXX_STANDARD=14
    "
    if ${with_warning}; then
        aggregator_options+="-DFALAISE_COMPILER_ERROR_ON_WARNING=ON "
    else
        aggregator_options+="-DFALAISE_COMPILER_ERROR_ON_WARNING=OFF "
    fi
    if ${with_doc}; then
        aggregator_options+="-DFALAISE_WITH_DOCS=ON "
    else
        aggregator_options+="-DFALAISE_WITH_DOCS=OFF "
    fi
    if ${with_test}; then
        aggregator_options+="-DFALAISE_ENABLE_TESTING=ON "
    else
        aggregator_options+="-DFALAISE_ENABLE_TESTING=OFF "
    fi

    __aggregator_set_compiler

    pkgtools::at_function_exit
    return 0
}

# end
