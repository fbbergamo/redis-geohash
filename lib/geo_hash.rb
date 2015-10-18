require "geohash/version"
require "redis"
require "json"

class GeoHash
  attr_accessor :member, :measure, :options, :redis

  def initialize(options = {})
    redis_host = options.fetch(:host, "localhost")
    redis_port = options.fetch(:port, 6379)
    redis_db = options.fetch(:db, 15)
    @options = options
    @member =  options.fetch(:member, "entity")
    @measure = options.fetch(:mesuare, "km")
    @redis = Redis.new(:host => redis_host, :port => redis_port, :db => redis_db)
  end

  def add_point(id, latitude, longitude)
    redis.set point_key(id), [latitude, longitude].to_json
    redis.geoadd(member, latitude, longitude, id)
  end

  def has_point?(id)
    redis.zscore(member, id).present? and redis.get point_key(id)
  end

  def remove_point(id)
    redis.zrem member, id
    redis.del point_key(id)
  end

  def point_key(id)
    "store_#{member}_#{id}"
  end

  # should be two  arrayies [latitude, longitude]
  def bouding_box_geohash(nw_point, se_point)
    nw_geohash = redis.geoencode(*nw_point)[0]
    se_geohash = redis.geoencode(*se_point)[0]
    [nw_geohash, se_geohash]
  end

  def search_bouding_box(nw_point, se_point, start = 1, last = 200)
    hashes = bouding_box_geohash(nw_point, se_point)
    hashes[1], hashes[0] = hashes[0], hashes[1] if hashes[0] > hashes[1]
    ids = redis.zrangebyscore member, *hashes, limit: [start, last]
    return false if ids and ids.count == 0
    ids_to_search = ids.map {|id| point_key(id) }
    positions = redis.mget *ids_to_search
    positions_convert = positions.map{|pos| JSON.parse(pos) if pos.present? }
    return Hash[ids.zip(positions_convert)]
  end

  def search_by_point(point, distance, count = 200)
    redis.georadius member, *point, distance, measure, "WITHDIST", "WITHCOORD"
  end



end
