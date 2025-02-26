/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#pragma once

#include <cstdint>

namespace moxygen {

/*
 * The stats in the MoQStatsCallback are common to both the publisher
 * and subscriber. The comments above each function describe when they're
 * called for each of the two roles.
 */
class MoQStatsCallback {
 public:
  virtual ~MoQStatsCallback() = default;

  /*
   * Publisher: Responded to a SUBSCRIBE request with a SUBSCRIBE_OK
   * Subscriber: Received a SUBSCRIBE_OK from the publisher
   */
  virtual void onSubscribeSuccess() = 0;

  /*
   * Publisher: Responded to a SUBSCRIBE request with a SUBSCRIBE_ERROR
   * Subscriber: Received a SUBSCRIBE_ERROR from the publisher
   */
  virtual void onSubscribeError(uint64_t errorCode) = 0;

  /*
   * Publisher: Responded to a FETCH request with a FETCH_OK
   * Subscriber: Received a FETCH_OK from the publisher
   */
  virtual void onFetchSuccess() = 0;

  /*
   * Publisher: Responded to a FETCH request with a FETCH_ERROR
   * Subscriber: Received a FETCH_ERROR from the publisher
   */
  virtual void onFetchError(uint64_t errorCode) = 0;

  // TODO: Add more stats
};

class MoQPublisherStatsCallback : public MoQStatsCallback {};

class MoQSubscriberStatsCallback : public MoQStatsCallback {};

} // namespace moxygen
