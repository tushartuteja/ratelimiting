module Limiting

  ##
  # A rate limiting module that can limit requests based on any time period.
  # @example allowing 100 requests every 6 hours
  #   add_limit 6.hours, 100
  # @example allowing 200 requests every day
  #   add_limit 1.day, 200
  #
  # You can even specify a controller to limit requests to all actions of a particular controller
  # @example allowing 100 requests every hour in home controller
  #   add_limit 1.hour, 100, controller: 'home'
  #
  # You can specify a controller and particular action to limit the requests
  # @example allowing 100 requests every hour in home controller and only index action
  #   add_limit 1.hour, 100, controller: 'home' , action: 'index'
  #


  def self.included base
    base.send :include, InstanceMethods
    base.send :before_action, :check_limit
    base.extend ClassMethods
  end

  module ClassMethods

    ##
    # Data store for holding Limit
    # @@general_limits stores application wide limits
    # @@controller_limits stores controller wide limits
    # @@action_limits stores action wide limits
    
    @@general_limits = []
    @@controller_limits = {}
    @@action_limits = {}


    ##
    # Get limits for the particular action controller
    #:@param controller
    #:@param action
    #:@return an array of limits

    def get_limits controller: nil, action: nil
      return @@general_limits + @@controller_limits[controller].to_a + @@action_limits[[controller, action]].to_a
    end


    ##
    # set limits
    #:@param time
    #:@param rate
    #:@param controller: optional
    #:@param action: optional

    def add_limit time, rate, controller: nil , action: nil
      if controller && action
        add_action_level_limit time, rate, controller, action
      else
        if controller
          add_controller_level_limit time, rate, controller
        else
          add_general_limit time, rate
        end
      end

    end

    private

    ##
    # set general limit,
    #:@param time
    #:@param rate

    def add_general_limit time, rate
      @@general_limits << {time: time, rate: rate, key: "limiting_module_general_#{time}"}
    end

    ##
    # set controller level limit,
    #:@param time
    #:@param rate
    #:@param controller
    
    def add_controller_level_limit time, rate , controller
      @@controller_limits[controller] ||=  []
      @@controller_limits[controller] << {time: time, rate: rate, key: "limiting_module_controller_#{controller}_#{time}"}
    end

    ##
    # set action level limit,
    #:@param time
    #:@param rate
    #:@param controller

    def add_action_level_limit time, rate, controller, action
      @@action_limits[[controller, action]] ||=  []
      @@action_limits[[controller, action]] << {time: time, rate: rate, key: "limiting_module_controller_#{controller}_#{action}_#{time}"}
    end
  end
  
  module InstanceMethods



    ##
    # Before action limit
    def check_limit

      # get limits for the current action
      
      limits = self.class.get_limits controller: params[:controller],action: params[:action]
      Rails.logger.info limits

      # max time one needs to wait
      max = -1
      limits.each do |limit|
        redis_key = "#{limit[:key]}_#{get_ip}"
        count = redis.get(redis_key)
        unless count
          reset_limit redis_key, limit[:rate],limit[:time]
        else
          if count.to_i > limit[:rate]
            expires = redis.ttl(redis_key)

            if expires <= 0
              reset_limit redis_key, limit[:rate],limit[:time]
            else
               if max < expires
                 max = expires
               end
            end
        end
        end
      end
      
      
      
      if max < 0

        limits.each do |limit|
          redis_key = "#{limit[:key]}_#{get_ip}"
          redis.incr(redis_key)
        end
        return true

      else
        render text: "Rate limit exceeded. Try again in #{max} seconds" , status: 429
      end
    end

    def get_ip
      request.env["REMOTE_ADDR"]
    end

    # get redis
    def redis
      @redis ||= Redis.current
    end

    ##
    # reset limit for the key
    #:@param key
    #:@param limit
    #:@param time


    def reset_limit  key, limit , time
      redis.set key , 1
      redis.expire key, time
    end
  end

end