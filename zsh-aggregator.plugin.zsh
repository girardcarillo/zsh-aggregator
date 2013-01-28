# -*- mode: shell-script; -*-
#
# Copyright (C) 2013 Xavier Garrido
#
# Author: garrido@lal.in2p3.fr
# Keywords: snailware, supernemo
# Requirements: pkgtools
# Status: not intended to be distributed yet

# Aggregator bundles
typeset -ga __aggregator_bundles
__aggregator_bundles=(cadfael bayeux channel falaise chevreuse)

declare -g aggregator_name
declare -g aggregator_svn_path
declare -g aggregator_branch_name
declare -g aggregator_base_dir
declare -g aggregator_logfile
declare -g aggregator_options
declare -g aggregator_config_version

function aggregator ()
{
    __pkgtools__default_values
    __pkgtools__at_function_enter aggregator

    local mode
    local append_list_of_options_arg
    local append_list_of_components_arg

    while [ -n "$1" ]; do
        local token="$1"
        if [ "${token[0,1]}" = "-" ]; then
	    local opt=${token}
            append_list_of_options_arg+="${opt} "
	    if [ "${opt}" = "-h" -o "${opt}" = "--help" ]; then
                return 0
	    elif [ "${opt}" = "-d" -o "${opt}" = "--debug" ]; then
	        pkgtools__msg_using_debug
	    elif [ "${opt}" = "-D" -o "${opt}" = "--devel" ]; then
	        pkgtools__msg_using_devel
	    elif [ "${opt}" = "-v" -o "${opt}" = "--verbose" ]; then
	        pkgtools__msg_using_verbose
	    elif [ "${opt}" = "-W" -o "${opt}" = "--no-warning" ]; then
	        pkgtools__msg_not_using_warning
	    elif [ "${opt}" = "-q" -o "${opt}" = "--quiet" ]; then
	        pkgtools__msg_using_quiet
	        export PKGTOOLS_MSG_QUIET=1
	    elif [ "${opt}" = "-i" -o "${opt}" = "--interactive" ]; then
	        pkgtools__ui_interactive
	    elif [ "${opt}" = "-b" -o "${opt}" = "--batch" ]; then
	        pkgtools__ui_batch
	    elif [ "${opt}" = "--gui" ]; then
	        pkgtools__ui_using_gui
           fi
        else
            if [ "${token}" = "environment" ]; then
                mode="environment"
            elif [ "${token}" = "configure" ]; then
                mode="configure"
            elif [ "${token}" = "build" ]; then
                mode="build"
            elif [ "${token}" = "rebuild" ]; then
                mode="rebuild"
            elif [ "${token}" = "reset" ]; then
                mode="reset"
            elif [ "${token}" = "setup" ]; then
                mode="setup"
            elif [ "${token}" = "test" ]; then
                mode="test"
            elif [ "${token}" = "svn-diff" ]; then
                mode="svn-diff"
            elif [ "${token}" = "svn-checkout" ]; then
                mode="svn-checkout"
            elif [ "${token}" = "svn-update" ]; then
                mode="svn-update"
            elif [ "${token}" = "git-checkout" ]; then
                mode="git-checkout"
            elif [ "${token}" = "git-update" ]; then
                mode="git-update"
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

    pkgtools__msg_devel "mode=${mode}"
    pkgtools__msg_devel "append_list_of_components_arg=${append_list_of_components_arg}"
    pkgtools__msg_devel "append_list_of_options_arg=${append_list_of_options_arg}"

    # Remove last space
    append_list_of_components_arg=${append_list_of_components_arg%?}
    append_list_of_options_arg=${append_list_of_options_arg%?}

    # Setting environment
    if [ ${mode} = environment ]; then
        __aggregator_environment
        __pkgtools__at_function_exit
        return 0
    else
        if [ ! -n "${SNAILWARE_SETUP_DONE}" ];then
            pkgtools__msg_warning "Setting default environment"
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
            pkgtools__msg_error "Aggregator '${icompo}' does not exist!"
            __pkgtools__at_function_exit
            return 1
        fi

        # Look for the corresponding directory
        pkgtools__msg_devel "repository=${SNAILWARE_PRO_DIR}/${icompo}/repo"
        local is_found=0
        pushd ${SNAILWARE_PRO_DIR}/${icompo}/repo > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            is_found=1
        fi

        if [ ${is_found} -eq 0 ]; then
            pkgtools__msg_error "Repository of '${icompo}' does not exist!"
            continue
        elif [ ${mode} = goto ]; then
            __pkgtools__at_function_exit
            return 0
        fi
        unset is_found

        # Set aggregator
        __aggregator_set_${icompo}

        case ${mode} in
            svn-update)
                pkgtools__msg_notice "Updating '${icompo}' aggregator"
                svn up
                if [ $? -ne 0 ]; then
                    pkgtools__msg_error "Updating '${icompo}' aggregator fails !"
                    break
                fi
                ;;
            git-update)
                pkgtools__msg_notice "Updating '${icompo}' aggregator"
                git svn fetch
                git svn rebase
                if [ $? -ne 0 ]; then
                    pkgtools__msg_error "Updating '${icompo}' aggregator fails !"
                    break
                fi
                ;;
            setup)
                pkgtools__msg_notice "Sourcing '${icompo}' aggregator"
                __aggregator_source_${icompo}
                ;;
            configure)
                pkgtools__msg_notice "Configuring '${icompo}' aggregator"
                __aggregator_set_${icompo}
                ;;
            build)
                pkgtools__msg_notice "Building '${icompo}' aggregator"
                __aggregator_build_${icompo}
                ;;
            reset)
                pkgtools__msg_notice "Reseting '${icompo}' aggregator"
                __aggregator_unsource_${icompo}
                __aggregator_remove_${icompo}
                ;;
            rebuild)
                pkgtools__msg_notice "Rebuilding '${icompo}' aggregator"
                aggregator ${append_list_of_options_arg} reset     ${icompo}
                aggregator ${append_list_of_options_arg} configure ${icompo}
                aggregator ${append_list_of_options_arg} build     ${icompo}
                aggregator ${append_list_of_options_arg} setup     ${icompo}
                ;;
            test)
                pkgtools__msg_notice "Testing '${icompo}' aggregator"
                ./pkgtools.d/pkgtool test
                 ;;
            svn-status)
                pkgtools__msg_notice "SVN status '${icompo}' aggregator"
                svnstatus
                ;;
            svn-diff)
                pkgtools__msg_notice "SVN diff '${icompo}' aggregator"
                svndiff
                ;;
        esac

        popd > /dev/null 2>&1
    done

    unset mode append_list_of_components_arg append_list_of_options_arg

    __pkgtools__at_function_exit
    return 0

}

function __aggregator_environment ()
{
    __pkgtools__at_function_enter __aggregator_environment

    if [ -n "${SNAILWARE_SETUP_DONE}" ]; then
        __pkgtools__at_function_exit
        return 0
    fi
    export SNAILWARE_SETUP_DONE=1

    # Take care of running machine
    case "${HOSTNAME}" in
        garrido-laptop)
            nemo_base_dir_tmp="/home/${USER}/Workdir/NEMO"
            nemo_pro_dir_tmp="${nemo_base_dir_tmp}/supernemo/snware"
            nemo_dev_dir_tmp="${nemo_base_dir_tmp}/supernemo/development"
            nemo_simulation_dir_tmp="${nemo_base_dir_tmp}/supernemo/simulations"
            ;;
        pc-91089)
            nemo_base_dir_tmp="/data/workdir/nemo/"
            nemo_pro_dir_tmp="${nemo_base_dir_tmp}/supernemo/snware"
            nemo_dev_dir_tmp="${nemo_base_dir_tmp}/supernemo/development"
            nemo_simulation_dir_tmp="${nemo_base_dir_tmp}/supernemo/simulations"
            ;;
        lx3.lal.in2p3.fr|nemo*.lal.in2p3.fr)
            nemo_base_dir_tmp="/exp/nemo/snsw"
            nemo_pro_dir_tmp="${nemo_base_dir_tmp}/supernemo/snware"
            nemo_dev_dir_tmp="/exp/nemo/${USER}/workdir/supernemo/development"
            nemo_simulation_dir_tmp="/scratch/${USER}/simulations"
            cadfael_version="0.1.0"
            ;;
        ccige*|ccage*)
            nemo_base_dir_tmp="/afs/in2p3.fr/group/nemo"
            nemo_pro_dir_tmp="${nemo_base_dir_tmp}/sw2"
            nemo_dev_dir_tmp="/sps/nemo/scratch/${USER}/workdir/supernemo/development"
            nemo_simulation_dir_tmp="/sps/nemo/scratch/${USER}/simulations"
            cadfael_version="0.2.1"
            cadfael_setup_file="${nemo_pro_dir_tmp}/Cadfael/Cadfael-${cadfael_version}/Install/etc/cadfael_setup.sh"
            ;;
        *)
            nemo_base_dir_tmp="/home/${USER}/Workdir"
            nemo_pro_dir_tmp="${nemo_base_dir_tmp}/supernemo/snware"
            nemo_dev_dir_tmp="${nemo_base_dir_tmp}/supernemo/development"
            ;;
    esac


    export SNAILWARE_BASE_DIR="${nemo_base_dir_tmp}"
    export SNAILWARE_PRO_DIR="${nemo_pro_dir_tmp}"
    export SNAILWARE_DEV_DIR="${nemo_dev_dir_tmp}"
    export SNSW_SIMULATION_DIR="${nemo_simulation_dir_tmp}"

    # Export main env. variables
    which ccache > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        export CXX="ccache g++"
        export CC="ccache gcc"
    fi

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_source ()
{
    __pkgtools__at_function_enter __aggregator_source

    pkgtools__msg_notice "Source '${aggregator_name}' aggregator"

    local upname=${aggregator_name:u}
    local install_dir=${aggregator_base_dir}/install/${aggregator_branch_name}
    export ${upname}_PREFIX=${install_dir}
    export ${upname}_INCLUDE_DIR=${install_dir}/include
    export ${upname}_BIN_DIR=${install_dir}/bin
    export ${upname}_SHARE_DIR=${install_dir}/share
    export ${upname}_ETC_DIR=${install_dir}/etc

    # Binaries
    pkgtools__add_path_to_PATH ${install_dir}/bin

    # Librairies
    if [ -d ${install_dir}/lib ]; then
        export ${upname}_LIB_DIR=${install_dir}/lib
        pkgtools__add_path_to_LD_LIBRARY_PATH ${install_dir}/lib
    elif [ -d ${install_dir}/lib64 ]; then
        export ${upname}_LIB_DIR=${install_dir}/lib64
        pkgtools__add_path_to_LD_LIBRARY_PATH ${install_dir}/lib64
    fi

    # cmake modules
    if [ -d ${install_dir}/share/cmake/Modules ]; then
        export ${upname}_DIR=${install_dir}/share/cmake/Modules
        pkgtools__add_path_to_env_variable CMAKE_MODULE_PATH ${install_dir}/share/cmake/Modules
    fi

    if [ ${aggregator_name} = cadfael ]; then
        export BOOST_ROOT=${CADFAEL_PREFIX}
        export GEANT4_ROOT_DIR=${CADFAEL_PREFIX}
        pkgtools__add_path_to_LD_LIBRARY_PATH ${CADFAEL_LIB_DIR}/root
    elif [ ${aggregator_name} = bayeux ]; then
        for i in ${install_dir}/share/*
        do
            local base=$(basename $i)
            local upbase=${base:u}
            export ${upbase}_DATA_DIR=${install_dir}/share/${base}
            unset base upbase
        done
    fi

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_unsource ()
{
    __pkgtools__at_function_enter __aggregator_unsource

    pkgtools__msg_notice "Un-source '${aggregator_name}' aggregator"

    local upname=${aggregator_name:u}
    local install_dir=${aggregator_base_dir}/install/${aggregator_branch_name}
    unset ${upname}_PREFIX
    unset ${upname}_INCLUDE_DIR
    unset ${upname}_LIB_DIR
    unset ${upname}_BIN_DIR
    unset ${upname}_SHARE_DIR
    unset ${upname}_ETC_DIR
    unset ${upname}_DIR

    pkgtools__remove_path_to_PATH ${install_dir}/bin
    pkgtools__remove_path_to_LD_LIBRARY_PATH ${install_dir}/lib
    pkgtools__remove_path_to_env_variable CMAKE_MODULE_PATH ${install_dir}/share/cmake/Modules

    if [ ${aggregator_name} = cadfael ]; then
        unset BOOST_ROOT
        unset GEANT4_ROOT_DIR
        pkgtools__remove_path_to_LD_LIBRARY_PATH ${CADFAEL_LIB_DIR}/root
    elif [ ${aggregator_name} = bayeux ]; then
        for i in ${install_dir}/share/*
        do
            local base=$(basename $i)
            local upbase=${base:u}
            unset ${upbase}_DATA_DIR
            unset base upbase
        done
    fi

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_set ()
{
    __pkgtools__at_function_enter __aggregator_set

    aggregator_logfile=/tmp/${aggregator_name}_${aggregator_branch_name}.log
    aggregator_base_dir=${SNAILWARE_PRO_DIR}/${aggregator_name}

    if [ ! -d  ${aggregator_base_dir}/repo ]; then
        pkgtools__msg_warning "${aggregator_base_dir}/repo directory not created"
        mkdir -p ${aggregator_base_dir}/repo
    fi
    cd ${aggregator_base_dir}/repo

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_get ()
{
    __pkgtools__at_function_enter __aggregator_get

    pkgtools__msg_notice "Getting/updating ${aggregator_name}"
    go-svn2git -username garrido -verbose ${aggregator_svn_path}
    git checkout ${aggregator_branch_name}

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_build ()
{
    __pkgtools__at_function_enter __aggregator_build

    pkgtools__msg_notice "Configure ${aggregator_name}"
    ./pkgtools.d/pkgtool configure                                                    \
        --install-prefix     ${aggregator_base_dir}/install/${aggregator_branch_name} \
        --ep-build-directory ${aggregator_base_dir}/build/${aggregator_branch_name}   \
        --download-directory ${aggregator_base_dir}/download                          \
        --config             ${aggregator_config_version}                             \
        ${aggregator_options} | tee -a ${aggregator_logfile} 2>&1

    pkgtools__msg_notice "Build/install ${aggregator_name}"
    ./pkgtools.d/pkgtool install | tee -a ${aggregator_logfile} 2>&1

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_remove ()
{
    __pkgtools__at_function_enter __aggregator_remove

    pkgtools__msg_notice "Remove ${aggregator_name}"
    echo y | ./pkgtools.d/pkgtool reset | tee -a ${aggregator_logfile} 2>&1

    rm -rf ${aggregator_base_dir}/{install,build}

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_set_cadfael
{
    __pkgtools__at_function_enter __aggregator_set_cadfael

    # Setting paths
    __aggregator_environment

    aggregator_name="cadfael"
    aggregator_branch_name="master"
    aggregator_svn_path="https://svn.lal.in2p3.fr/users/garrido/Workdir/NEMO/SuperNEMO/Cadfael"
    aggregator_options="--with-all             \
                        --without-mysql	       \
			--without-hdf5	       \
			--without-systemc      \
			--without-python       \
			--root-version 5.34.03 \
			--boost-version 1.51.0 \
			--with-test"
    __aggregator_set

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_source_cadfael ()
{
    __pkgtools__at_function_enter __aggregator_source_cadfael

    __aggregator_set_cadfael
    __aggregator_source

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_unsource_cadfael ()
{
    __pkgtools__at_function_enter __aggregator_unsource_cadfael

    __aggregator_set_cadfael
    __aggregator_unsource

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_remove_cadfael ()
{
    __pkgtools__at_function_enter __agregator_remove_cadfael

    (
        __aggregator_set_cadfael
        __aggregator_remove
    )

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_build_cadfael ()
{
    __pkgtools__at_function_enter __aggregator_build_cadfael

     (
         __aggregator_set_cadfael
         __aggregator_get
         __aggregator_build
    )

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_set_bayeux ()
{
    __pkgtools__at_function_enter __aggregator_set_bayeux

    # Building Bayeux
    aggregator_name="bayeux"
    aggregator_branch_name="master"
    aggregator_svn_path="https://nemo.lpc-caen.in2p3.fr/svn/Bayeux"
    aggregator_config_version="legacy"
    aggregator_options="--with-all  \
                        --with-test"
    __aggregator_set

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_source_bayeux ()
{
    __pkgtools__at_function_enter __aggregator_source_bayeux

    __aggregator_set_bayeux
    __aggregator_source

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_unsource_bayeux ()
{
    __pkgtools__at_function_enter __aggregator_unsource_bayeux

    __aggregator_set_bayeux
    __aggregator_unsource

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_remove_bayeux ()
{
    __pkgtools__at_function_enter __aggregator_remove_bayeux

    (
        __aggregator_set_bayeux
        __aggregator_remove
    )

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_build_bayeux ()
{
    __pkgtools__at_function_enter __aggregator_build_bayeux

    (
        __aggregator_environment
        __aggregator_source_cadfael
        __aggregator_set_bayeux
        __aggregator_get
        __aggregator_build
    )

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_set_channel ()
{
    __pkgtools__at_function_enter __aggregator_set_channel

    aggregator_name="channel"
    aggregator_branch_name="master"
    aggregator_svn_path="https://nemo.lpc-caen.in2p3.fr/svn/snsw/devel/Channel"
    aggregator_config_version="trunk"
    aggregator_options="--with-all \
                        --with-test"
    __aggregator_set

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_source_channel ()
{
    __pkgtools__at_function_enter __aggregator_source_channel

    __aggregator_set_channel
    __aggregator_source

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_unsource_channel ()
{
    __pkgtools__at_function_enter __aggregator_unsource_channel

    __aggregator_set_channel
    __aggregator_unsource

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_remove_channel ()
{
    __pkgtools__at_function_enter __aggregator_remove_channel

    (
        __aggregator_set_channel
        __aggregator_remove
    )

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_build_channel ()
{
    __pkgtools__at_function_enter __aggregator_build_channel

    (
        __aggregator_environment
        __aggregator_source_cadfael
        __aggregator_set_channel
        __aggregator_get
        __aggregator_build
    )

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_set_falaise ()
{
    __pkgtools__at_function_enter __aggregator_set_falaise

    aggregator_name="falaise"
    aggregator_branch_name="master"
    aggregator_svn_path="https://nemo.lpc-caen.in2p3.fr/svn/snsw/devel/Falaise"
    aggregator_config_version="trunk"
    aggregator_options="--with-all        \
                        --with-snanalysis \
                        --with-test"
    __aggregator_set

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_source_falaise ()
{
    __pkgtools__at_function_enter __aggregator_source_falaise

    __aggregator_set_falaise
    __aggregator_source

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_unsource_falaise ()
{
    __pkgtools__at_function_enter __aggregator_unsource_falaise

    __aggregator_set_falaise
    __aggregator_unsource

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_remove_falaise ()
{
    __pkgtools__at_function_enter __aggregator_remove_falaise

    (
        __aggregator_set_falaise
        __aggregator_remove
    )

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_build_falaise ()
{
    __pkgtools__at_function_enter __aggregator_build_falaise

    (
        __aggregator_environment
        __aggregator_source_cadfael
        __aggregator_source_bayeux
        __aggregator_source_channel
        __aggregator_set_falaise
        __aggregator_get
        __aggregator_build
    )

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_set_chevreuse ()
{
    __pkgtools__at_function_enter __aggregator_set_chevreuse

    aggregator_name="chevreuse"
    aggregator_branch_name="master"
    aggregator_svn_path="https://nemo.lpc-caen.in2p3.fr/svn/snsw/devel/Chevreuse"
    aggregator_options="--with-all  \
                        --with-test"
    __aggregator_set

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_source_chevreuse ()
{
    __pkgtools__at_function_enter __aggregator_source_chevreuse

    __aggregator_set_chevreuse
    __aggregator_source

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_unsource_chevreuse ()
{
    __pkgtools__at_function_enter __aggregator_unsource_chevreuse

    __aggregator_set_chevreuse
    __aggregator_unsource

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_remove_chevreuse ()
{
    __pkgtools__at_function_enter __aggregator_remove_chevreuse

    (
        __aggregator_set_chevreuse
        __aggregator_remove
    )

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_build_chevreuse ()
{
    __pkgtools__at_function_enter __aggregator_build_chevreuse

    (
        __aggregator_environment
        __aggregator_source_cadfael
        __aggregator_source_bayeux
        __aggregator_source_falaise
        __aggregator_set_chevreuse
        __aggregator_get
        __aggregator_build
    )

    __pkgtools__at_function_exit
    return 0
}

# end
