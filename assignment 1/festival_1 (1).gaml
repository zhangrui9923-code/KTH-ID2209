/**
* Name: Festival Simulation
* Author: Rui
* Description: 节日仿真 - 游客在节日中寻找食物和水
* Tags: agent-based, simulation, festival
*/

model FestivalSimulation

global {
    // 全局参数
    int nb_guests <- 15;  // 游客数量
    int nb_stores <- 6;   // 商店数量
    float world_size <- 100.0;
    
    // 信息中心位置（世界中心）
    point info_center_location <- {world_size/2, world_size/2};
    
    init {
        // 创建信息中心
        create InformationCenter number: 1 {
            location <- info_center_location;
        }
        
        // 创建商店 - 3个食物店，3个饮料店
        create Store number: nb_stores {
            location <- {rnd(world_size), rnd(world_size)};
            store_type <- flip(0.5) ? "FOOD" : "WATER";
        }
        
        // 创建游客 - 50%有记忆系统，50%无记忆系统
        create Guest number: nb_guests {
            location <- {rnd(world_size), rnd(world_size)};
            hunger <- rnd(50.0, 100.0);
            thirst <- rnd(50.0, 100.0);
            // 10%的游客是坏人
            is_bad <- flip(0.1);
            // 挑战1: 50%的游客有记忆系统（大脑）
            has_memory <- flip(0.5);
        }
        
        // 创建保安
        create SecurityGuard number: 1 {
            location <- info_center_location + {5, 5};
        }
    }
}

// 游客代理
species Guest skills: [moving] {
    // 属性
    float hunger <- 100.0 min: 0.0 max: 100.0;
    float thirst <- 100.0 min: 0.0 max: 100.0;
    float hunger_threshold <- 30.0;
    float thirst_threshold <- 30.0;
    float speed <- 1.0;
    
    // 状态
    string state <- "idle" among: ["idle", "seeking_info", "going_to_store", "at_store"];
    point target_location <- nil;
    Store target_store <- nil;
    
    // 坏人属性
    bool is_bad <- false;
    bool reported <- false;
    
    // 挑战1: 记忆系统
    bool has_memory <- true;  // 是否有记忆系统（大脑）
    list<Store> memory <- [];  // 记忆的商店列表
    float total_distance <- 0.0;  // 总移动距离
    point last_location <- location;
    
    reflex decrease_needs when: state = "idle" {
        // 随机减少饥饿和口渴值
        hunger <- hunger - rnd(0.5, 1.5);
        thirst <- thirst - rnd(0.5, 1.5);
        
        // 随机移动
        do wander speed: speed * 0.3;
    }
    
    reflex check_needs when: state = "idle" {
        if (hunger < hunger_threshold or thirst < thirst_threshold) {
            // 挑战1关键改进：有记忆的游客可以直接去商店！
            if (has_memory and length(memory) > 0) {
                // 确定需要什么类型
                string needed_type <- hunger < thirst ? "FOOD" : "WATER";
                
                // 70%概率使用记忆，30%去信息中心探索新地方
                if (flip(0.7)) {
                    // 从记忆中选择合适类型的商店
                    list<Store> suitable_memory <- memory where (each.store_type = needed_type);
                    if (length(suitable_memory) > 0) {
                        // 直接去记忆中最近的商店！
                        target_store <- suitable_memory closest_to location;
                        target_location <- target_store.location;
                        state <- "going_to_store";
                    } else {
                        // 记忆中没有合适的，去信息中心询问
                        state <- "seeking_info";
                    }
                } else {
                    // 30%概率探索新地方，去信息中心
                    state <- "seeking_info";
                }
            } else {
                // 无记忆的游客必须去信息中心
                state <- "seeking_info";
            }
        }
    }
    
    reflex go_to_info_center when: state = "seeking_info" {
        // 前往信息中心
        target_location <- info_center_location;
        do goto target: target_location speed: speed;
        
        if (location distance_to info_center_location < 2.0) {
            // 到达信息中心，询问最近的商店
            ask InformationCenter at_distance 5.0 {
                // 确定需要什么类型的商店
                string needed_type <- myself.hunger < myself.thirst ? "FOOD" : "WATER";
                
                // 无论有无记忆，来到这里的都需要询问
                myself.target_store <- self.find_nearest_store(myself.location, needed_type);
                
                if (myself.target_store != nil) {
                    myself.target_location <- myself.target_store.location;
                    myself.state <- "going_to_store";
                }
            }
        }
    }
    
    reflex go_to_store when: state = "going_to_store" and target_store != nil {
        do goto target: target_location speed: speed;
        
        if (location distance_to target_location < 2.0) {
            state <- "at_store";
        }
    }
    
    reflex replenish when: state = "at_store" and target_store != nil {
        // 补充需求
        if (target_store.store_type = "FOOD") {
            hunger <- 100.0;
        } else if (target_store.store_type = "WATER") {
            thirst <- 100.0;
        }
        
        // 挑战1: 只有有记忆的游客才会记住商店
        if (has_memory and !(memory contains target_store)) {
            add target_store to: memory;
        }
        
        // 重置状态
        state <- "idle";
        target_store <- nil;
        target_location <- nil;
    }
    
    // 挑战1: 追踪移动距离
    reflex track_distance {
        total_distance <- total_distance + (location distance_to last_location);
        last_location <- location;
    }
    
    // 挑战2: 好游客发现坏人后去报告
    reflex report_bad_behavior when: !is_bad and flip(0.3) {
        // 在自己周围找还没有被举报的坏人
        list<Guest> bad_nearby <- Guest at_distance 10.0 where(each.is_bad and !each.reported);
        if (length(bad_nearby) > 0) {
        	Guest bad_guest <- one_of(bad_nearby);
        	
            // 被报告到信息中心
            ask one_of(InformationCenter) {
                do report_bad_guest(bad_guest);
            }
            
        }
    }
    
    aspect default {
        if (is_bad and !reported) {
            draw circle(1.5) color: #red;  // 坏游客 - 红色
        } else if (is_bad and reported) {
            draw circle(1.5) color: #darkred;  // 被举报的坏游客 - 深红色
        } else if (has_memory) {
            draw circle(1) color: #blue;  // 有记忆的游客 - 蓝色
        } else {
            draw circle(1) color: #gray;  // 无记忆的游客 - 灰色
        }
        
        // 显示状态
        draw string(state) size: 3 color: #black at: location + {0, 2};
    }
}

// 商店代理
species Store {
    string store_type <- "FOOD" among: ["FOOD", "WATER"];
    
    aspect default {
        if (store_type = "FOOD") {
            draw square(3) color: #orange;  // 食物店 - 橙色
            draw "F" size: 5 color: #white at: location;
        } else {
            draw square(3) color: #cyan;    // 饮料店 - 青色
            draw "W" size: 5 color: #white at: location;
        }
    }
}

// 信息中心代理
species InformationCenter {
    
    // 查找最近的特定类型商店
    Store find_nearest_store(point guest_location, string needed_type) {
        list<Store> matching_stores <- Store where (each.store_type = needed_type);
        
        if (length(matching_stores) = 0) {
            return nil;
        }
        
        Store nearest <- matching_stores closest_to guest_location;
        return nearest;
    }
    
    // 挑战2: 报告坏游客
    action report_bad_guest(Guest bad_guest) {
        write "Information Center: Bad guest reported!";
        
        ask bad_guest{
        	reported <- true;
        }
        
      
    }
    
    aspect default {
        draw triangle(4) color: #green;  // 信息中心 - 绿色三角形
        draw "INFO" size: 4 color: #white at: location + {0, 3};
    }
}

// 挑战2: 保安代理
species SecurityGuard skills: [moving] {
    Guest target_bad_guest <- nil;
    float speed <- 2.0;  // 保安移动更快
    string state <- "idle" among: ["idle", "chasing"];
    
    action chase_bad_guest(Guest bad_guest) {
        target_bad_guest <- bad_guest;
        state <- "chasing";
    }
    
    reflex chase when: state = "chasing" and target_bad_guest != nil {
        do goto target: target_bad_guest.location speed: speed;
        
        // 如果接近坏游客，移除他
        if (location distance_to target_bad_guest.location < 2.0) {
            write "Security Guard: Bad guest removed from festival!";
            ask target_bad_guest {
                do die;
            }
            target_bad_guest <- nil;
            state <- "idle";
            // 返回信息中心
            do goto target: info_center_location speed: speed;
        }
    }
    
    reflex look_for_reported when: state = "idle"{
    	//找所有is_bad且reported = true 的坏人
    	list<Guest> targets <- Guest where (each.is_bad and each.reported);
    	
    	if(length(targets) > 0){
    		//随机挑一个
    		Guest bad_guest <- one_of(targets);
    		do chase_bad_guest(bad_guest);
    	}
    }
    
    reflex return_to_base when: state = "idle" and location distance_to info_center_location > 5.0 {
        do goto target: info_center_location speed: speed * 0.5;
    }
    
    aspect default {
        draw circle(1.5) color: #black;  // 保安 - 黑色
        draw "S" size: 4 color: #white at: location;
        
        if (state = "chasing") {
            draw line([location, target_bad_guest.location]) color: #red width: 2;
        }
    }
}

// 实验配置
experiment FestivalSimulation type: gui {
    parameter "Number of Guests" var: nb_guests min: 5 max: 50 category: "Setup";
    parameter "Number of Stores" var: nb_stores min: 2 max: 20 category: "Setup";
    
    output {
        display main_display {
            // 显示所有代理
            species Store aspect: default;
            species InformationCenter aspect: default;
            species Guest aspect: default;
            species SecurityGuard aspect: default;
        }
        
        // 挑战1: 监控游客移动距离
        monitor "Total Guests" value: length(Guest);
        monitor "Guests WITH Memory (Brain)" value: length(Guest where each.has_memory) color: #blue;
        monitor "Guests WITHOUT Memory" value: length(Guest where !each.has_memory) color: #gray;
        monitor "Bad Guests" value: length(Guest where each.is_bad);
        
        // 距离对比 - 这是挑战1的关键数据
        monitor "Avg Distance (WITH Memory)" value: length(Guest where each.has_memory) > 0 ? 
            mean((Guest where each.has_memory) collect each.total_distance) : 0.0 color: #blue;
        monitor "Avg Distance (WITHOUT Memory)" value: length(Guest where !each.has_memory) > 0 ? 
            mean((Guest where !each.has_memory) collect each.total_distance) : 0.0 color: #gray;
        monitor "Distance Saved %" value: length(Guest where !each.has_memory) > 0 ? 
            ((mean((Guest where !each.has_memory) collect each.total_distance) - 
              mean((Guest where each.has_memory) collect each.total_distance)) / 
             mean((Guest where !each.has_memory) collect each.total_distance) * 100) : 0.0 color: #green;
        
        // 游客状态分布
        monitor "Idle Guests" value: length(Guest where (each.state = "idle"));
        monitor "Seeking Info (going to IC)" value: length(Guest where (each.state = "seeking_info")) color: #orange;
        monitor "Going to Store (direct)" value: length(Guest where (each.state = "going_to_store")) color: #green;
        monitor "At Store" value: length(Guest where (each.state = "at_store"));
        
        // 图表：显示游客平均饥饿和口渴水平
        display charts {
            chart "Average Guest Needs" type: series {
                data "Average Hunger" value: mean(Guest collect each.hunger) color: #orange;
                data "Average Thirst" value: mean(Guest collect each.thirst) color: #cyan;
            }
        }
        
        // 挑战1: 距离对比图表 - 这是挑战1的核心可视化
        display distance_chart {
            chart "Challenge 1: Distance Traveled Comparison" type: series {
                data "WITH Memory (Brain)" 
                    value: length(Guest where each.has_memory) > 0 ? 
                        mean((Guest where each.has_memory) collect each.total_distance) : 0.0 
                    color: #blue marker: true;
                data "WITHOUT Memory" 
                    value: length(Guest where !each.has_memory) > 0 ? 
                        mean((Guest where !each.has_memory) collect each.total_distance) : 0.0 
                    color: #gray marker: true;
            }
        }
        
        // 记忆大小随时间变化
        display memory_chart {
            chart "Memory Size Over Time" type: series {
                data "Avg Stores Remembered" 
                    value: length(Guest where each.has_memory) > 0 ? 
                        mean((Guest where each.has_memory) collect length(each.memory)) : 0.0 
                    color: #purple;
            }
        }
    }
}
