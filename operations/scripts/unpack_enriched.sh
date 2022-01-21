#!/bin/bash
# Copyright (C) 2021 by Samsung Electronics Co., Ltd.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#     http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License



TMP_DIR=../a1-pe-sim-packages/resources/oran-sim-cba/tmp

if [ -d $TMP_DIR ]
then
	cd $TMP_DIR

	unzip cba_enriched.zip
	cp -rf Definitions ..
	cp -rf Scripts ..
	cp -rf Templates ..
	cp -rf TOSCA-Metadata ..

	rm -rf Definitions
	rm -rf Scripts
	rm -rf Templates
	rm -rf TOSCA-Metadata


	rm *.zip
	cd ..
	rm -rf tmp
fi

