cmake_minimum_required (VERSION 3.13)

include_guard(GLOBAL)

message(STATUS   "\n")
message(STATUS   ":===================:")
message(STATUS   ":loading utils.cmake:")
message(STATUS   ":===================:\n")

# message function override
function(message)
  list(GET ARGV 0 MessageType)
  list(REMOVE_AT ARGV 0)
  if(MessageType STREQUAL DEBUG)
	if(VERBOSE)
		_message(STATUS "[debug] ${ARGV}")
	endif()
  else()
    _message(${MessageType} "${ARGV}")
  endif()
endfunction()

macro(setup_package)

    SET(options)
	SET(oneValueArgs NAME)
	SET(multiValueArgs)

	cmake_parse_arguments(
		SETUP_PACKAGE 
		"${options}"
		"${oneValueArgs}" 
		"${multiValueArgs}" 
		${ARGN})

	STRING(TOUPPER ${SETUP_PACKAGE_NAME} UCASE)

	MESSAGE(DEBUG "${SETUP_PACKAGE_NAME} package setup ...")

	# allows override of the user used
	IF(DEFINED ${UCASE}_CONAN_USER)
		MESSAGE(STATUS "${libname} user has been overriden to ${${UCASE}_CONAN_USER}")
	else()
		SET(${UCASE}_CONAN_USER ${CONAN_USER})
	endif()

	# allows override of the channel used
	IF(DEFINED ${UCASE}_CONAN_CHANNEL)
		MESSAGE(STATUS "${libname} channel has been overriden to ${${UCASE}_CONAN_CHANNEL}")
	else()
		SET(${UCASE}_CONAN_CHANNEL ${CONAN_CHANNEL})
	endif()

	list(APPEND REPOS "${SETUP_PACKAGE_NAME}/${${UCASE}_VERS}@${${UCASE}_CONAN_USER}/${${UCASE}_CONAN_CHANNEL}")

endmacro()

macro(load_packages)

    SET(options UPDATE)
	SET(oneValueArgs OPTIONS SETTINGS PROFILE)
	SET(multiValueArgs NAME)

	cmake_parse_arguments(
		LOAD_PACKAGES "${options}"
		"${oneValueArgs}" "${multiValueArgs}" ${ARGN})

	foreach(PKG ${LOAD_PACKAGES_NAME})
		setup_package(NAME ${PKG})
	endforeach(PKG)

	MESSAGE(STATUS "packages to be loaded: ${REPOS} with configuration ${CMAKE_BUILD_TYPE}, settings ${LOAD_PACKAGES_SETTINGS} and options ${LOAD_PACKAGES_OPTIONS}")

	IF (${LOAD_PACKAGES_UPDATE})
		conan_cmake_run(
			REQUIRES ${REPOS}
			SETTINGS ${LOAD_PACKAGES_SETTINGS}
			OPTIONS ${LOAD_PACKAGES_OPTIONS}
			BASIC_SETUP CMAKE_TARGETS
			BASIC_SETUP KEEP_RPATHS
			BUILD missing
			BUILD_TYPE ${CMAKE_BUILD_TYPE}
			PROFILE ${LOAD_PACKAGES_PROFILE}
			UPDATE ON
		)
	ELSE()
	conan_cmake_run(
		REQUIRES ${REPOS}
		SETTINGS ${CONAN_EXTRA_SETTINGS}
		OPTIONS ${CONAN_EXTRA_OPTIONS}
		BASIC_SETUP CMAKE_TARGETS
		BASIC_SETUP KEEP_RPATHS
		BUILD missing
		BUILD_TYPE ${CMAKE_BUILD_TYPE}
		PROFILE ${LOAD_PACKAGES_PROFILE}
	)
	ENDIF()

	conan_global_flags()

	foreach(PKG ${REPO})
		string(TOUPPER ${PKG} UCASE)
		if(${UCASE}_CMAKE_CONFIG)
			MESSAGE(DEBUG "${UCASE}_CMAKE_CONFIG has been defined. Looking for ${PKG}Config.cmake...")
			find_package(${PKG} REQUIRED HINTS CONAN_${PKG}_ROOT)
			if (${${PKG}_FOUND})
				MESSAGE(STATUS "${PKG} package ... Found")
			else()
				MESSAGE(FATAL_ERROR "${PKG} package ... Not Found !")
			endif()
		endif()
	endforeach(PKG)
endmacro()

function(setup_component)

    SET(options)
	SET(oneValueArgs TARGET)
	SET(multiValueArgs)

	cmake_parse_arguments(
		SETUP_COMPONENT 
		"${options}"
		"${oneValueArgs}" 
		"${multiValueArgs}" ${ARGN}
	)

	MESSAGE(DEBUG "setting target library ${SETUP_COMPONENT_TARGET}")

	set(TARGET_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR} PARENT_SCOPE)
	MESSAGE(DEBUG "${SETUP_COMPONENT_TARGET} source folder set to ${TARGET_SOURCE_DIR}")

	GET_PROPERTY(TMP GLOBAL PROPERTY ProjectTargets)
	SET(TMP "${TMP};${SETUP_COMPONENT_TARGET}")
	MESSAGE(DEBUG "ProjectTargets values: ${TMP}")
	SET_PROPERTY(GLOBAL PROPERTY ProjectTargets "${TMP}")
endfunction()

function(install_binary)

	SET(options)
	SET(oneValueArgs NAME TARGET COMPONENT)
	SET(multiValueArgs)

	cmake_parse_arguments(
		INSTALL_BINARY
		"${options}"
		"${oneValueArgs}"
		"${multiValueArgs}" ${ARGN})

	if (INSTALL_BINARY_COMPONENT)
	else()
		SET(INSTALL_BINARY_COMPONENT Unspecified)
	endif()

	# add the component to the component list
	#GET_PROPERTY(tmp GLOBAL PROPERTY ProjectComponents)
	#SET(tmp "${tmp};${INSTALL_BINARY_PACKAGE}")
	#list(REMOVE_DUPLICATES tmp)
	#MESSAGE(DEBUG "Project components is set to: ${tmp}")
	#SET_PROPERTY(GLOBAL PROPERTY ProjectComponents "${tmp}")

	MESSAGE(DEBUG "set ${INSTALL_BINARY_TARGET} install path to ${CMAKE_INSTALL_PREFIX}/bin")
	MESSAGE(DEBUG "adding target ${TARGET_NAME} to package ${INSTALL_BINARY_PACKAGE}")
	MESSAGE(DEBUG "${TARGET_NAME} binary name set to ${BINARY_NAME}")

	set_target_properties(${TARGET_NAME} PROPERTIES OUTPUT_NAME "${BINARY_NAME}")

	INSTALL(
		TARGETS ${TARGET_NAME}
		RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}/bin/${TARGET_INSTALL_SUBFOLDER}"
		COMPONENT ${INSTALL_BINARY_COMPONENT}
	)

endfunction()

macro(enable_testing)

	MESSAGE(DEBUG "CONAN_GTEST_ROOT value set to ${CONAN_GTEST_ROOT}")
	if (DEFINED CONAN_GTEST_ROOT)
		include(GoogleTest)
	else()
	endif()

	MESSAGE(DEBUG "enabling testing ...")
	_enable_testing()

endmacro()
