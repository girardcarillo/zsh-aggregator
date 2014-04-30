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
__aggregator_bundles=(cadfael bayeux falaise)
typeset -g __aggregator_use_make=false

function aggregator ()
{
    __pkgtools__default_values
    __pkgtools__at_function_enter aggregator

    local mode
    local append_list_of_options_arg
    local append_list_of_components_arg
    local with_test=false

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
            elif [ "${opt}" = "--with-test" ]; then
	        with_test=true
            elif [ "${opt}" = "--without-test" ]; then
	        with_test=false
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
                __aggregator_update
                if $(pkgtools__last_command_fails); then
                    pkgtools__msg_error "Updating '${icompo}' aggregator fails !"
                    break
                fi
                ;;
            setup)
                pkgtools__msg_notice "Sourcing '${icompo}' aggregator"
                __aggregator_setup
                if $(pkgtools__last_command_fails); then
                    pkgtools__msg_error "Sourcing '${icompo}' aggregator fails !"
                    break
                fi
                ;;
            unsetup)
                pkgtools__msg_notice "Un-Sourcing '${icompo}' aggregator"
                __aggregator_unsetup
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
                __aggregator_unsetup
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
                __aggregator_test
                if $(pkgtools__last_command_fails); then
                    pkgtools__msg_error "Testing '${icompo}' aggregator fails !"
                    break
                fi
                ;;
        esac

        popd > /dev/null 2>&1
    done

    unset mode append_list_of_components_arg append_list_of_options_arg
    unset with_test
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
            nemo_pro_dir_tmp="${nemo_base_dir_tmp}/supernemo/new_snware"
            nemo_simulation_dir_tmp="${nemo_base_dir_tmp}/supernemo/simulations"
            nemo_build_dir_tmp="${nemo_pro_dir_tmp}"
            ;;
    esac

    if env | grep -q "^SNAILWARE_BASE_DIR="; then
        pkgtools__set_variable SNAILWARE_PRO_DIR        "$SNAILWARE_BASE_DIR/new_snware"
        pkgtools__set_variable SNAILWARE_BUILD_DIR      "$SNAILWARE_PRO_DIR"
    else
        # Export only if it is not already exported
        pkgtools__set_variable SNAILWARE_BASE_DIR       "${nemo_base_dir_tmp}"
        pkgtools__set_variable SNAILWARE_PRO_DIR        "${nemo_pro_dir_tmp}"
        pkgtools__set_variable SNAILWARE_BUILD_DIR      "${nemo_build_dir_tmp}"
        pkgtools__set_variable SNAILWARE_SIMULATION_DIR "${nemo_simulation_dir_tmp}"
    fi

    #compdef _gnu_generic bxdpp_processing
    compdef _genbb_inspector bxgenbb_inspector
    compdef _dpp_processing  bxdpp_processing
    compdef _ocd_manual      bxocd_manual

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_setup ()
{
    __pkgtools__at_function_enter __aggregator_setup

    local upname=${aggregator_name:u}
    local install_dir=${aggregator_base_dir}/install

    # Binaries
    pkgtools__add_path_to_PATH ${install_dir}/bin

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_unsetup ()
{
    __pkgtools__at_function_enter __aggregator_unsetup

    local upname=${aggregator_name:u}
    local install_dir=${aggregator_base_dir}/install

    pkgtools__remove_path_to_PATH ${install_dir}/bin

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
    aggregator_logfile=/tmp/${USER}/${aggregator_name}.log
    aggregator_base_dir=${SNAILWARE_PRO_DIR}/${aggregator_name}
    aggregator_repo_dir=${aggregator_base_dir}/repo
    aggregator_build_dir=${aggregator_base_dir}/build
    aggregator_install_dir=${aggregator_base_dir}/install

    if [ ! -d ${aggregator_build_dir} ]; then
        mkdir -p ${aggregator_build_dir}
    fi

    if [ ! -d  ${aggregator_repo_dir} ]; then
        pkgtools__msg_warning "${aggregator_repo_dir} directory not created"
        mkdir -p ${aggregator_repo_dir}
    fi

    if ! ${__aggregagtor_use_make}; then
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
        pkgtools__msg_debug "Machine has go-svn2git"
        go-svn2git -username ${USER} -verbose ${aggregator_svn_path/trunk/}
        if $(pkgtools__last_command_fails); then
            pkgtools__msg_error "Checking out fails!"
            __pkgtools__at_function_exit
            return 1
        fi
        if [ ${icompo} = bayeux ]; then
            pkgtools__msg_debug "Component ${icompo}"
            components=(datatools
                mygsl
                materials
                geomtools
                brio
                cuts
                genvtx
                emfield
                dpp
                genbb_help
                mctools
            )
            for jcompo in ${=components}
            do
                pkgtools__msg_notice "Getting external component ${jcompo}"
                (
                    cd ${aggregator_repo_dir}/source && mkdir -p bx${jcompo}
                    cd bx${jcompo}
                    go-svn2git -username ${USER} -verbose \
                        https://nemo.lpc-caen.in2p3.fr/svn/${jcompo}
                    if $(pkgtools__last_command_fails); then
                        pkgtools__msg_error "Checking out fails!"
                        __pkgtools__at_function_exit
                        return 1
                    fi
                )
            done
        elif [ ${icompo} = falaise ]; then
            pkgtools__msg_debug "Component ${icompo}"
            pkgtools__msg_notice "Getting external component CAT"
            (
                cd ${aggregator_repo_dir}/modules/CAT && mkdir -p CellularAutomatonTracker
                cd CellularAutomatonTracker
                go-svn2git -username ${USER} -verbose \
                    https://nemo.lpc-caen.in2p3.fr/svn/snsw/devel/Channel/Components/CellularAutomatonTracker
                if $(pkgtools__last_command_fails); then
                    pkgtools__msg_error "Getting CAT fails!"
                    __pkgtools__at_function_exit
                    return 1
                fi
            )
        fi
    elif $(pkgtools__has_binary svn); then
        pkgtools__msg_debug "Machine has subversion"
        svn checkout ${aggregator_svn_path} .
        if $(pkgtools__last_command_fails); then
            pkgtools__msg_error "Checking out fails!"
            __pkgtools__at_function_exit
            return 1
        fi
    else
        pkgtools__msg_warning "Machine has no subversion installed"
        __pkgtools__at_function_exit
        return 1
    fi

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_update ()
{
    __pkgtools__at_function_enter __aggregator_update

    if $(pkgtools__has_binary go-svn2git); then
        pkgtools__msg_debug "Machine has go-svn2git"
        git svn fetch
        git svn rebase
        if $(pkgtools__last_command_fails); then
            pkgtools__msg_error "Updating fails!"
            __pkgtools__at_function_exit
            return 1
        fi
        if [ ${icompo} = bayeux ]; then
            pkgtools__msg_debug "Component ${icompo}"
            components=(datatools
                mygsl
                materials
                geomtools
                brio
                cuts
                genvtx
                emfield
                dpp
                genbb_help
                mctools
            )
            for jcompo in ${=components}
            do
                pkgtools__msg_notice "Updating external component ${jcompo}"
                (
                    cd ${aggregator_repo_dir}/source/bx${jcompo}
                    git svn fetch
                    git svn rebase
                    if $(pkgtools__last_command_fails); then
                        pkgtools__msg_error "Updating ${jcompo} fails!"
                        __pkgtools__at_function_exit
                        return 1
                    fi
                )
            done
        elif [ ${icompo} = falaise ]; then
            pkgtools__msg_debug "Component ${icompo}"
            pkgtools__msg_notice "Updating external component CAT"
            (
                cd ${aggregator_repo_dir}/modules/CAT/CellularAutomatonTracker
                git svn fetch
                git svn rebase
                if $(pkgtools__last_command_fails); then
                    pkgtools__msg_error "Updating CAT fails!"
                    __pkgtools__at_function_exit
                    return 1
                fi
            )
        fi
    elif $(pkgtools__has_binary svn); then
        pkgtools__msg_debug "Machine has subversion"
        svn update
        if $(pkgtools__last_command_fails); then
            pkgtools__msg_error "Updating fails!"
            __pkgtools__at_function_exit
            return 1
        fi
    else
        pkgtools__msg_warning "Machine has no subversion installed"
        __pkgtools__at_function_exit
        return 1
    fi

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_configure ()
{
    __pkgtools__at_function_enter __agregator_configure

    if ! ${__aggregator_use_make}; then
        aggregator_options+="-G Ninja -DCMAKE_MAKE_PROGRAM=$(pkgtools__get_binary_path ninja)"
    fi

    pkgtools__msg_devel "aggregator options=${aggregator_options}"

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

    # Cadfael has no install build command
    local build_options
    if [ ${aggregator_name} != cadfael ]; then
        build_options="install"
    fi

    if ${__aggregator_use_make}; then
        make ${build_options} | tee -a ${aggregator_logfile} 2>&1
        if $(pkgtools__last_command_fails); then
            pkgtools__msg_error "Installation fails!"
            __pkgtools__at_function_exit
            return 1
        fi
    else
        ninja ${build_options} | tee -a ${aggregator_logfile} 2>&1
        if $(pkgtools__last_command_fails); then
            pkgtools__msg_error "Installation fails!"
            __pkgtools__at_function_exit
            return 1
        fi
    fi

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_test ()
{
    __pkgtools__at_function_enter __aggregator_test

    pkgtools__msg_devel "aggregator build dir=${aggregator_build_dir}"
    cd ${aggregator_build_dir}

    if ${__aggregator_use_make}; then
        make test | tee -a ${aggregator_logfile} 2>&1
        if $(pkgtools__last_command_fails); then
            pkgtools__msg_error "Test fails!"
            __pkgtools__at_function_exit
            return 1
        fi
    else
        ninja test | tee -a ${aggregator_logfile} 2>&1
        if $(pkgtools__last_command_fails); then
            pkgtools__msg_error "Test fails!"
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
    aggregator_svn_path="https://nemo.lpc-caen.in2p3.fr/svn/Cadfael/trunk"

    __aggregator_set
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
    unset CXX
    unset CC
    __aggregator_use_make=true

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_set_bayeux
{
    __pkgtools__at_function_enter __aggregator_set_bayeux

    # Retrieve Cadfael information
    __aggregator_set_cadfael
    __aggregator_set
    local cadfael_install_dir=${aggregator_install_dir}
    pkgtools__msg_devel "cadfael_install_dir=${cadfael_install_dir}"

    aggregator_name="bayeux"
    aggregator_svn_path="https://nemo.lpc-caen.in2p3.fr/svn/Bayeux/trunk"
    __aggregator_set
    aggregator_options="                                 \
        -DCMAKE_INSTALL_PREFIX=${aggregator_install_dir} \
        -DCMAKE_PREFIX_PATH=${cadfael_install_dir}       \
        -DBayeux_WITH_GEANT4=ON
    "
    if ${with_test}; then
        aggregator_options+="-DBayeux_ENABLE_TESTING=ON "
    else
        aggregator_options+="-DBayeux_ENABLE_TESTING=OFF "
    fi

    if $(pkgtools__has_binary ccache); then
        export CXX='ccache g++'
        export CC='ccache gcc'
    fi

    __pkgtools__at_function_exit
    return 0
}

function __aggregator_set_falaise
{
    __pkgtools__at_function_enter __aggregator_set_falaise

    # Retrieve Cadfael information
    __aggregator_set_cadfael
    __aggregator_set
    local cadfael_install_dir=${aggregator_install_dir}
    pkgtools__msg_devel "cadfael_install_dir=${cadfael_install_dir}"
    __aggregator_set_bayeux
    __aggregator_set
    local bayeux_install_dir=${aggregator_install_dir}
    pkgtools__msg_devel "bayeux_install_dir=${bayeux_install_dir}"

    aggregator_name="falaise"
    aggregator_svn_path="https://nemo.lpc-caen.in2p3.fr/svn/Falaise/trunk"
    __aggregator_set
    aggregator_options="                                                 \
        -DCMAKE_INSTALL_PREFIX=${aggregator_install_dir}                 \
        -DCMAKE_PREFIX_PATH=${cadfael_install_dir};${bayeux_install_dir} \
        -DFalaise_BUILD_DOCS=ON                                          \
        -DFalaise_USE_SYSTEM_BAYEUX=ON                                   \
        -DFalaise_BUILD_DEVELOPER_TOOLS=ON
    "
    if ${with_test}; then
        aggregator_options+="-DFalaise_ENABLE_TESTING=ON "
    else
        aggregator_options+="-DFalaise_ENABLE_TESTING=OFF "
    fi

    # Use ccache if any
    if $(pkgtools__has_binary ccache); then
        export CXX='ccache g++'
        export CC='ccache gcc'
    fi

    __pkgtools__at_function_exit
    return 0
}

# end
