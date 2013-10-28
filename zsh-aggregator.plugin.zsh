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
__aggregator_bundles=(cadfael bayeux channel falaise)

typeset -g __aggregator_use_make=false

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
            elif [ "${opt}" = "--use-make" ]; then
                __aggregator_use_make=true
            elif [ "${opt}" = "--use-ninja" ]; then
                __aggregator_use_make=false
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
        if [ ! -n "${AGGREGATOR_SETUP_DONE}" ];then
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

        # Set aggregator
        __aggregator_set_${icompo}

        # Look for the corresponding directory
        pkgtools__msg_devel "repository=${SNAILWARE_PRO_DIR}/${icompo}/repo"
        local is_found=false
        pushd ${aggregator_repo_dir} > /dev/null 2>&1
        if $(pkgtools__last_command_succeeds); then
            is_found=true
        fi

        if ! ${is_found}; then
            pkgtools__msg_error "Repository of '${icompo}' does not exist!"
            continue
        elif [ ${mode} = goto ]; then
            __pkgtools__at_function_exit
            return 0
        fi
        unset is_found

        case ${mode} in
            checkout)
                pkgtools__msg_notice "Getting '${icompo}' aggregator"
                __aggregator_get
                if $(pkgtools__last_command_fails); then
                    pkgtools__msg_error "Getting '${icompo}' aggregator fails !"
                    break
                fi
                ;;
            update)
                pkgtools__msg_notice "Updating '${icompo}' aggregator"
                git svn fetch && git svn rebase
                if $(pkgtools__last_command_fails); then
                    pkgtools__msg_error "Updating '${icompo}' aggregator fails !"
                    break
                fi
                ;;
            setup)
                pkgtools__msg_notice "Sourcing '${icompo}' aggregator"
                __aggregator_source
                if $(pkgtools__last_command_fails); then
                    pkgtools__msg_error "Sourcing '${icompo}' aggregator fails !"
                    break
                fi
                ;;
            unsetup)
                pkgtools__msg_notice "Un-Sourcing '${icompo}' aggregator"
                __aggregator_unsource
                if $(pkgtools__last_command_fails); then
                    pkgtools__msg_error "Un-Sourcing '${icompo}' aggregator fails !"
                    break
                fi
                ;;
            configure)
                pkgtools__msg_notice "Configuring '${icompo}' aggregator"
                __aggregator_configure
                if $(pkgtools__last_command_fails); then
                    pkgtools__msg_error "Configuring '${icompo}' aggregator fails !"
                    break
                fi
                ;;
            build)
                pkgtools__msg_notice "Building '${icompo}' aggregator"
                __aggregator_get
                __aggregator_configure
                __aggregator_build
                if $(pkgtools__last_command_fails); then
                    pkgtools__msg_error "Building '${icompo}' aggregator fails !"
                    break
                fi
                ;;
            dump)
                pkgtools__msg_notice "Dumping '${icompo}' aggregator"
                __aggregator_dump
                if $(pkgtools__last_command_fails); then
                    pkgtools__msg_error "Dumping '${icompo}' aggregator fails !"
                    break
                fi
                ;;
            reset)
                pkgtools__msg_notice "Reseting '${icompo}' aggregator"
                __aggregator_unsource
                __aggregator_remove
                if $(pkgtools__last_command_fails); then
                    pkgtools__msg_error "Reseting '${icompo}' aggregator fails !"
                    break
                fi
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
                ;;
        esac

        popd > /dev/null 2>&1
    done

    unset mode append_list_of_components_arg append_list_of_options_arg
    __pkgtools__default_values
    __pkgtools__at_function_exit
    return 0

}

function __aggregator_environment ()
{
    __pkgtools__at_function_enter __aggregator_environment

    if [ -n "${AGGREGATOR_SETUP_DONE}" ]; then
        __pkgtools__at_function_exit
        return 0
    fi
    export AGGREGATOR_SETUP_DONE=1

    # Take care of running machine
    case "${HOSTNAME}" in
        garrido-laptop)
            nemo_base_dir_tmp="/home/${USER}/Workdir/NEMO"
            nemo_pro_dir_tmp="${nemo_base_dir_tmp}/supernemo/snware_test"
            nemo_dev_dir_tmp="${nemo_base_dir_tmp}/supernemo/development"
            nemo_simulation_dir_tmp="${nemo_base_dir_tmp}/supernemo/simulations"
            nemo_build_dir_tmp="${nemo_pro_dir_tmp}"
            ;;
        pc-91089)
            nemo_base_dir_tmp="/data/workdir/nemo/"
            nemo_pro_dir_tmp="${nemo_base_dir_tmp}/supernemo/snware"
            nemo_dev_dir_tmp="${nemo_base_dir_tmp}/supernemo/development"
            nemo_simulation_dir_tmp="${nemo_base_dir_tmp}/supernemo/simulations"
            nemo_build_dir_tmp="${nemo_pro_dir_tmp}"
            ;;
        lx3.lal.in2p3.fr|nemo*.lal.in2p3.fr)
            nemo_base_dir_tmp="/exp/nemo/snsw"
            nemo_pro_dir_tmp="${nemo_base_dir_tmp}/supernemo/snware"
            nemo_dev_dir_tmp="/exp/nemo/${USER}/workdir/supernemo/development"
            nemo_simulation_dir_tmp="/exp/nemo/${USER}/workdir/supernemo/simulations"
            nemo_build_dir_tmp="/scratch/${USER}/snware"
            ;;
        ccige*|ccage*)
            nemo_base_dir_tmp="/sps/nemo/scratch/${USER}/workdir"
            nemo_pro_dir_tmp="${nemo_base_dir_tmp}/supernemo/snware"
            nemo_dev_dir_tmp="${nemo_base_dir_tmp}/supernemo/development"
            nemo_simulation_dir_tmp="/sps/nemo/scratch/${USER}/simulations"
            nemo_build_dir_tmp="/scratch/${USER}/snware"
            ;;
        *)
            nemo_base_dir_tmp="/home/${USER}/Workdir"
            nemo_pro_dir_tmp="${nemo_base_dir_tmp}/supernemo/snware"
            nemo_dev_dir_tmp="${nemo_base_dir_tmp}/supernemo/development"
            nemo_build_dir_tmp="${nemo_pro_dir_tmp}"
            ;;
    esac

    if env | grep -q "^SNAILWARE_BASE_DIR="; then
        pkgtools__set_variable SNAILWARE_PRO_DIR        "$SNAILWARE_BASE_DIR/snware_test"
        pkgtools__set_variable SNAILWARE_DEV_DIR        "$SNAILWARE_BASE_DIR/development"
        pkgtools__set_variable SNAILWARE_BUILD_DIR      "$SNAILWARE_PRO_DIR"
    else
        # Export only if it is not already exported
        pkgtools__set_variable SNAILWARE_BASE_DIR       "${nemo_base_dir_tmp}"
        pkgtools__set_variable SNAILWARE_PRO_DIR        "${nemo_pro_dir_tmp}"
        pkgtools__set_variable SNAILWARE_DEV_DIR        "${nemo_dev_dir_tmp}"
        pkgtools__set_variable SNAILWARE_SIMULATION_DIR "${nemo_simulation_dir_tmp}"
        pkgtools__set_variable SNAILWARE_BUILD_DIR      "${nemo_build_dir_tmp}"
    fi

    # Export main env. variables
    # if $(pkgtools__has_binary ccache); then
    #     export CXX='ccache g++'
    #     export CC='ccache gcc'
    # fi

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_source ()
{
    __pkgtools__at_function_enter __aggregator_source

    local upname=${aggregator_name:u}
    local install_dir=${aggregator_base_dir}/install/${aggregator_branch_name}
    # export ${upname}_PREFIX=${install_dir}
    # export ${upname}_INCLUDE_DIR=${install_dir}/include
    # export ${upname}_BIN_DIR=${install_dir}/bin
    # export ${upname}_SHARE_DIR=${install_dir}/share
    # export ${upname}_ETC_DIR=${install_dir}/etc

    # Binaries
    pkgtools__add_path_to_PATH ${install_dir}/bin

    # Librairies
    # if [ -d ${install_dir}/lib ]; then
    #     pkgtools__set_variable ${upname}_LIB_DIR ${install_dir}/lib
    #     pkgtools__add_path_to_LD_LIBRARY_PATH ${install_dir}/lib
    # elif [ -d ${install_dir}/lib64 ]; then
    #     pkgtools__set_variable ${upname}_LIB_DIR ${install_dir}/lib64
    #     pkgtools__add_path_to_LD_LIBRARY_PATH ${install_dir}/lib64
    # fi

    # cmake modules
    # if [ -d ${install_dir}/share/cmake/Modules ]; then
    #     export ${upname}_DIR=${install_dir}/share/cmake/Modules
    #     pkgtools__add_path_to_env_variable CMAKE_MODULE_PATH ${install_dir}/share/cmake/Modules
    # fi

    # if [ ${aggregator_name} = cadfael ]; then
    #     pkgtools__set_variable BOOST_ROOT      ${CADFAEL_PREFIX}
    #     pkgtools__set_variable GEANT4_ROOT_DIR ${CADFAEL_PREFIX}
    #     pkgtools__set_variable CAMP_DIR        ${CADFAEL_PREFIX}
    #     pkgtools__set_variable CAMP_LIBRARIES  ${CADFAEL_LIB_DIR}
    #     pkgtools__add_path_to_LD_LIBRARY_PATH ${CADFAEL_LIB_DIR}/root
    # else
    #     for i in ${install_dir}/share/*
    #     do
    #         local base=$(basename $i)
    #         local upbase=${base:u}
    #         export ${upbase}_DATA_DIR=${install_dir}/share/${base}
    #         unset base upbase
    #     done
    # fi

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_unsource ()
{
    __pkgtools__at_function_enter __aggregator_unsource

    local upname=${aggregator_name:u}
    local install_dir=${aggregator_base_dir}/install/${aggregator_branch_name}
    # unset ${upname}_PREFIX
    # unset ${upname}_INCLUDE_DIR
    # unset ${upname}_LIB_DIR
    # unset ${upname}_BIN_DIR
    # unset ${upname}_SHARE_DIR
    # unset ${upname}_ETC_DIR
    # unset ${upname}_DIR

    pkgtools__remove_path_to_PATH ${install_dir}/bin
    # pkgtools__remove_path_to_LD_LIBRARY_PATH ${install_dir}/lib
    # pkgtools__remove_path_to_env_variable CMAKE_MODULE_PATH ${install_dir}/share/cmake/Modules

    # if [ ${aggregator_name} = cadfael ]; then
    #     unset BOOST_ROOT
    #     unset GEANT4_ROOT_DIR
    #     pkgtools__remove_path_to_LD_LIBRARY_PATH ${CADFAEL_LIB_DIR}/root
    # else
    #     for i in ${install_dir}/share/*
    #     do
    #         local base=$(basename $i)
    #         local upbase=${base:u}
    #         unset ${upbase}_DATA_DIR
    #         unset base upbase
    #     done
    # fi

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_set ()
{
    __pkgtools__at_function_enter __aggregator_set

    __aggregator_environment

    if [ ! -d /tmp/${USER} ]; then
        mkdir -p /tmp/${USER}
    fi
    aggregator_logfile=/tmp/${USER}/${aggregator_name}_${aggregator_branch_name}.log
    aggregator_base_dir=${SNAILWARE_PRO_DIR}/${aggregator_name}
    aggregator_repo_dir=${aggregator_base_dir}/repo
    aggregator_build_dir=${aggregator_base_dir}/build/${aggregator_branch_name}
    aggregator_install_dir=${aggregator_base_dir}/install/${aggregator_branch_name}

    if [ ! -d ${aggregator_build_dir} ]; then
        mkdir -p ${aggregator_build_dir}
    fi

    if [ ! -d  ${aggregator_repo_dir} ]; then
        pkgtools__msg_warning "${aggregator_repo_dir} directory not created"
        mkdir -p ${aggregator_repo_dir}
    fi

    if ! ${__aggregator_use_make}; then
        if ! $(pkgtools__has_binary ninja); then
            pkgtools__msg_error "Ninja binary has not been found !"
            __pkgtools__at_function_exit
            return 1
        fi
    fi

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_get ()
{
    __pkgtools__at_function_enter __aggregator_get

    if $(pkgtools__has_binary go-svn2git); then
        pkgtools__msg_notice "Machine has go-svn2git"
        go-svn2git -username nemo -verbose ${aggregator_svn_path}
        if $(pkgtools__last_command_fails); then
            pkgtools__msg_error "Checking fails!"
            __pkgtools__at_function_exit
            return 1
        fi
    else
        pkgtools__msg_notice "Machine does not have go-svn2git"
        git svn init --prefix=svn/ --username=nemo --trunk=trunk --tags=tags --branches=branches \
            ${aggregator_svn_path}
        git svn fetch
        if $(pkgtools__last_command_fails); then
            pkgtools__msg_error "Checking fails!"
            __pkgtools__at_function_exit
            return 1
        fi
    fi
    git checkout ${aggregator_branch_name}
    if $(pkgtools__last_command_fails); then
        pkgtools__msg_error "Branch ${aggregator_branch_name} does not exist!"
        __pkgtools__at_function_exit
        return 1
    fi

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_configure ()
{
    __pkgtools__at_function_enter __agregator_configure

    cd ${aggregator_build_dir}

    cmake                             \
        $(echo ${aggregator_options}) \
        ${aggregator_repo_dir} | tee -a ${aggregator_logfile} 2>&1
    if $(pkgtools__last_command_fails); then
        pkgtools__msg_error "Configuration fails!"
        __pkgtools__at_function_exit
        return 1
    fi

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_build ()
{
    __pkgtools__at_function_enter __aggregator_build

    pkgtools__msg_devel "use make=${__aggregator_use_make}"
    cd ${aggregator_build_dir}

    if ${__aggregator_use_make}; then
        make install | tee -a ${aggregator_logfile} 2>&1
        if $(pkgtools__last_command_fails); then
            pkgtools__msg_error "Installation fails!"
            __pkgtools__at_function_exit
            return 1
        fi
    else
        ninja | tee -a ${aggregator_logfile} 2>&1
        if $(pkgtools__last_command_fails); then
            pkgtools__msg_error "Installation fails!"
            __pkgtools__at_function_exit
            return 1
        fi
    fi

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_remove ()
{
    __pkgtools__at_function_enter __aggregator_remove

    rm -rf ${aggregator_install_dir}
    rm -rf ${aggregator_build_dir}

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_dump ()
{
    __pkgtools__at_function_enter __aggregator_dump

    pkgtools__msg_notice "Dump aggregator"
    pkgtools__msg_notice " |- name           : ${aggregator_name}"
    pkgtools__msg_notice " |- branch         : ${aggregator_branch_name}"
    pkgtools__msg_notice " |- repository     : ${aggregator_svn_path}"
    pkgtools__msg_notice " |- options        : ${aggregator_options}"
    pkgtools__msg_notice " |- config version : ${aggregator_config_version}"
    pkgtools__msg_notice " |- install dir.   : ${aggregator_install_dir}"
    pkgtools__msg_notice " \`- build dir.    : ${aggregator_build_dir}"

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_set_cadfael
{
    __pkgtools__at_function_enter __aggregator_set_cadfael

    aggregator_name="cadfael"
    aggregator_branch_name="master"
    aggregator_svn_path="https://nemo.lpc-caen.in2p3.fr/svn/Cadfael"
    aggregator_options="                                 \
        -DCMAKE_INSTALL_PREFIX=${aggregator_install_dir} \
        -DCADFAEL_VERBOSE_BUILD=ON                       \
        -DCADFAEL_STEP_TARGETS=ON                        \
        -Dport/patchelf=ON                               \
        -Dport/gsl=ON                                    \
        -Dport/clhep=ON                                  \
        -Dport/boost=ON                                  \
        -Dport/boost+regex=ON                            \
        -Dport/camp=ON                                   \
        -Dport/xerces-c=ON                               \
        -Dport/geant4=ON                                 \
        -Dport/geant4+gdml=ON                            \
        -Dport/geant4+x11=ON                             \
        -Dport/geant4+data=ON                            \
        -Dport/root=ON                                   \
        -Dport/root+x11=ON                               \
        -Dport/root+asimage=ON                           \
        -Dport/root+mathmore=ON                          \
        -Dport/root+opengl=ON
    "

    if ! ${__aggregator_use_make}; then
        aggregator_options+="-G Ninja -DCMAKE_MAKE_PROGRAM=$(pkgtools__get_binary_path ninja)"
    fi

    __aggregator_set

    __pkgtools__at_function_exit
    return 0
}

# end
