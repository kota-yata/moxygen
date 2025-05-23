/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

// Use this main function in gtest unit tests to enable glog
#include <folly/init/Init.h>
#include <folly/portability/GFlags.h>
#include <folly/portability/GTest.h>
#include <glog/logging.h>

int main(int argc, char* argv[]) {
  testing::InitGoogleTest(&argc, argv);
  folly::Init init(&argc, &argv, true);
  LOG(INFO) << "Running tests from TestMain.cpp";
  return RUN_ALL_TESTS();
}
