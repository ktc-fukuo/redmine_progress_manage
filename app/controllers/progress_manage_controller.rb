class ProgressManageController < ApplicationController

    #
    # 初期表示
    #
    def index
    end

    #
    # 休日リスト
    #
    def holidays
        jsonText = "{"
        ActualHoliday.all.order(holiday: "DESC").each{|actualHoliday|
            if jsonText != "{" then
                jsonText += ","
            end
            jsonText += "\"" + actualHoliday.holiday.to_s + "\":\"1\""
        }
        jsonText += "}"
        render json: JSON.parse(jsonText)
    end

    #
    # プロジェクトリスト
    #
    def projects
        render json: ActiveRecord::Base.connection.execute("select * from projects where status = 1 order by id")
    end

    #
    # ステータスリスト
    #
    def statuses
        jsonText = "{"
        IssueStatus.all.order(:id).each{|status|
            if jsonText != "{" then
                jsonText += ","
            end
            jsonText += "\"" + status.id.to_s + "\":\"" + status.name + "\""
        }
        jsonText += "}"
        render json: JSON.parse(jsonText)
    end

    #
    # ユーザーリスト
    #
    def users
        # jsonText = "{"
        # User.all.order(:id).each{|user|
            # if jsonText != "{" then
                # jsonText += ","
            # end
            # jsonText += "\"" + user.id.to_s + "\":\"" + user.lastname + " " + user.firstname + "\""
        # }
        # jsonText += "}"
        # render json: JSON.parse(jsonText)

        # users = User.where("(type = 'User' and admin = 0) or type = 'Group'").all.order(:type).order(:login).order(:id)
        # render json: users

        render json: ActiveRecord::Base.connection.execute("select * from users where (type = 'User' and admin = 0) or type = 'Group' order by type, login, id")
    end

    #
    # チケット実積リスト
    #
    def search
        jsonText = "{"
        Issue
        .joins("INNER JOIN issue_statuses    ist on ist.id = issues.status_id ")
        .joins("LEFT OUTER JOIN actual_spans s   on s.issue_id = issues.id")
        .joins("LEFT OUTER JOIN versions     v   on v.id = issues.fixed_version_id")
        .joins(:project)
        .select("issues.*, s.id as actual_span_id, s.bo_days, s.bo_date, s.days, s.suspends, s.man_days, s.eo_date, s.eo_days, projects.name as project_name, v.name as version")
        .where(["issues.tracker_id != 3 and ist.is_closed = :closed and ist.id in (1,2,4,7,9)", {:closed => false}])
        .all
        .order(:bo_date).order('ifnull(issues.start_date, "9999-99-99")').order(:project_id).order(:fixed_version_id).order('issues.priority_id desc').order(:id)
        .each{|actualSpan|
            if jsonText != "{" then
                jsonText += ","
            end
            jsonText += "\"#" + actualSpan.id.to_s + "\":{"
            jsonText += "\"id\":\"#" + actualSpan.id.to_s + "\","
            jsonText += "\"projectId\":\"" + actualSpan.project_id.to_s + "\","
            jsonText += "\"projectName\":\"" + actualSpan.project_name + "\","
            
            version = ""
            if actualSpan.version != nil then
            	version = actualSpan.version
            end
            jsonText += "\"version\":\"" + version + "\","
            
            status_id = ""
            if actualSpan.status_id != nil then
            	status_id = actualSpan.status_id
            end
            jsonText += "\"statusId\":\"" + status_id.to_s + "\","
            
            assigned_to_id = ""
            if actualSpan.assigned_to_id != nil then
            	assigned_to_id = actualSpan.assigned_to_id
            end
            jsonText += "\"assignedId\":\"" + assigned_to_id.to_s + "\","
            
            jsonText += "\"startDate\":\"" + actualSpan.start_date.to_s + "\","
            jsonText += "\"dueDate\":\"" + actualSpan.due_date.to_s + "\","
            jsonText += "\"subject\":\"" + actualSpan.subject + "\","
            jsonText += "\"lockVersion\":\"" + actualSpan.lock_version.to_s + "\","
            jsonText += "\"actualSpanId\":\"" + actualSpan.actual_span_id.to_s + "\","
            jsonText += "\"boDays\":\"" + actualSpan.bo_days.to_s + "\","
            jsonText += "\"boDate\":\"" + actualSpan.bo_date.to_s + "\","
            jsonText += "\"days\":\"" + actualSpan.days.to_s + "\","
            jsonText += "\"suspends\":\"" + actualSpan.suspends.to_s + "\","
            jsonText += "\"manDays\":\"" + actualSpan.man_days.to_s + "\","
            jsonText += "\"eoDate\":\"" + actualSpan.eo_date.to_s + "\","
            jsonText += "\"eoDays\":\"" + actualSpan.eo_days.to_s + "\""
            jsonText += "}"
        }
        jsonText += "}"
        render json: JSON.parse(jsonText)
    end

    #
    # 休日リスト洗い替え
    #
    def setHolidays
        ActualHoliday.delete_all()
        params.each{|k,v|
            next if k == "controller"
            next if k == "action"
            sql = "INSERT INTO actual_holidays (holiday) VALUES ('" + k + "')"
            ActiveRecord::Base.connection.execute(sql)
        }
        render json: params
    end

    #
    # チケット更新
    #
    def putIssue

        sql = "UPDATE issues "
        sql += "SET "
        sql += "    status_id = " + params[:status_id]
        if params[:assigned_to_id] == "" then
	        sql += "    , assigned_to_id = null"
        else
	        sql += "    , assigned_to_id = " + params[:assigned_to_id]
        end
        if params[:start_date] == "" then
	        sql += "    , start_date = null"
        else
	        sql += "    , start_date = '" + params[:start_date] + "'"
        end
        if params[:due_date] == "" then
	        sql += "    , due_date = null"
        else
	        sql += "    , due_date = '" + params[:due_date] + "'"
        end
        sql += " WHERE "
        sql += "    id = " + params[:id]
        ActiveRecord::Base.connection.execute(sql)
        issue = Issue.find(params[:id])
        render json: issue
    end

    #
    # 実績日数更新
    #
    def putActualSpan
        permitted = params.permit(:id, :issue_id, :bo_days, :bo_date, :days, :suspends, :man_days, :eo_date, :eo_days)
        actualSpan = ActualSpan.where(["issue_id = :issue_id", {:issue_id => params[:issue_id]}]).all
        if actualSpan.count == 0 then
            actualSpan = ActualSpan.create(permitted)
        else
        actualSpan.update(permitted)
        end
        render json: actualSpan
    end

end
