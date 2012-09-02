class FacebookController < ApplicationController
  def index
        auth_hash = request.env['omniauth.auth']
        #render :text => auth_hash[:token]
        token = auth_hash["credentials"]["token"]
        session[:token] = token
        redirect_to :action => "likes"
        return
        #render :text => auth_hash["credentials"]["token"]
  end
  
  def likes
      if not session[:token]
          return redirect_to '/'
      end
      token = session[:token]
      @token = token
      query = URI::encode({
          :mylikes => "SELECT object_id, post_id, object_type FROM like WHERE user_id=me()",
          :likes =>  "SELECT object_id, user_id FROM like WHERE object_id IN (SELECT object_id FROM #mylikes)",
          :friends => "SELECT uid, name FROM user WHERE uid IN (SELECT user_id FROM #likes) AND uid IN (SELECT uid1 FROM friend WHERE uid2=me())"
        }.to_json()
      )
      #url = "https://graph.facebook.com/fql?q=#{query}&access_token=#{token}"
      result = HTTParty.post("https://graph.facebook.com/",
        {
          :body => {
            :access_token => token,
            :batch => [
                {
                    :method => "GET",
                    :relative_url => "fql?q=#{query}"
                },
            ].to_json()
          }
        }
      );
      json = ActiveSupport::JSON.decode(result[0]["body"])
      @result = []
      friendsList = json["data"][2]["fql_result_set"]
      friends = {}
      for f in friendsList
          friends[f["uid"]] = f
      end
      myLikesList = json["data"][0]["fql_result_set"]
      likes = {}
      #likesList = ActiveSupport::JSON.decode(result[1]["body"])["data"]
      for l in myLikesList
          likes[l["object_id"]] = l
      end
      @result = {}
      relationsList = json["data"][1]["fql_result_set"]
      for r in relationsList
          if @result[r["object_id"]]
              if friends[r["user_id"]]
                @result[r["object_id"]][:users].push(friends[r["user_id"]])
              end
          else
              if likes[r["object_id"]] and friends[r["user_id"]]
                  @result[r["object_id"]] = {
                    :like => likes[r["object_id"]],
                    :users => [friends[r["user_id"]]]
                  }
              end
          end
      end
      return
      for i in @result
          render :json=>i[1][:like]
          return
      end

      render :json => @result
      return
  end
end
