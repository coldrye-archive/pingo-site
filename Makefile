# vim: noexpandtab:ts=4:sw=4

# Copyright 2015 Carsten Klein
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


build_dir       = ./build
dist_dir        = ./dist
src_dir         = ./src

include Makefile.conf


.PHONY: dist build-assets build-externals build-src \
		bower clean clean-build clean-dist \
        deps deps-global deploy undeploy


undeployed_marker = $(build_dir)/undeployed


# transpiles both src and test
dist: clean $(build_dir)/ $(dist_dir)/ build-src build-assets build-externals bower
	@cd build && wintersmith build


build-src:
	cp -vr $(src_dir)/* $(build_dir)


$(build_dir)/:
	@mkdir $(build_dir)
	@ln -s ../node_modules $(build_dir)/


$(dist_dir)/:
	@mkdir $(dist_dir)


bower:
	@bower install


# internal
build-assets:
	@echo "gathering assets..."
	@if [ ! -z "$(artwork_dir)" ]; then \
		mkdir -p $(build_dir)/contents/images; \
		cp $(artwork_dir)/dist/favicon.png $(build_dir)/contents/; \
		cp $(artwork_dir)/dist/logo.png $(build_dir)/contents/images/logo.png; \
	fi


# internal
build-externals:
	@echo "building externals..."
	@for pdir in $(project_dirs); do \
		echo $$pdir; \
		lpdir=$$(basename $$pdir); \
		make -C $$pdir cover doc; \
		mkdir -p $(build_dir)/contents/projects/$$lpdir; \
		cp -a $$pdir/build/doc build/contents/projects/$$lpdir/doc; \
		cp -a $$pdir/build/cover build/contents/projects/$$lpdir/cover; \
	done


# cleans both the build and dist directory 
clean: clean-build clean-dist


# internal
clean-build:
	@echo "cleaning build..."
	@-rm -Rf $(build_dir)


# internal
clean-dist:
	@echo "cleaning dist..."
	@-rm -Rf $(dist_dir)


# installs local (dev) dependencies
deps:
	@echo "installing local (dev) dependencies..."
	@npm install 


# installs global dev dependencies
deps-global:
	@echo "installing global dev dependencies (sudo)..."
	@sudo npm -g install $(shell node -e " \
		var pkg = require('./package.json'); \
		var deps = []; \
        for (var key in pkg.globalDevDependencies) { \
			var version = pkg.globalDevDependencies[key]; \
			if (version.indexOf('/') != -1) { \
				deps.push(version); \
			} \
			else { \
				deps.push('\"' + key + '@' + version + '\"'); \
			} \
		} \
		console.log(deps.join(' ')); \
    ")


# deploys the site
deploy: dist undeploy
	@echo "deploying to $(deploy_host)"
	@scp .$(deploy_conf)/sites-available/$(deploy_name).$(deploy_fqdn) $(deploy_user)@$(deploy_host):$(deploy_conf)/sites-available/$(deploy_name).$(deploy_fqdn)
	@ssh $(deploy_user)@$(deploy_host) -C "ln -s $(deploy_conf)/sites-available/$(deploy_name).$(deploy_fqdn) $(deploy_conf)/sites-enabled/"
	@scp -r $(dist_dir) $(deploy_user)@$(deploy_host):$(deploy_root)/$(deploy_name).$(deploy_fqdn)
	@ssh $(deploy_user)@$(deploy_host) -C "service nginx reload"
	@rm $(undeployed_marker)


# undeploys the site
undeploy: $(undeployed_marker)


# internal
$(undeployed_marker):
	@echo "undeploying from $(deploy_host)"
	@ssh $(deploy_user)@$(deploy_host) -C "rm -f $(deploy_conf)/sites-available/$(deploy_name).$(deploy_fqdn)"
	@ssh $(deploy_user)@$(deploy_host) -C "rm -f $(deploy_conf)/sites-enabled/$(deploy_name).$(deploy_fqdn)"
	@ssh $(deploy_user)@$(deploy_host) -C "service nginx reload"
	@ssh $(deploy_user)@$(deploy_host) -C "rm -Rf $(deploy_root)/$(deploy_name).$(deploy_fqdn)"
	@touch $(undeployed_marker)

