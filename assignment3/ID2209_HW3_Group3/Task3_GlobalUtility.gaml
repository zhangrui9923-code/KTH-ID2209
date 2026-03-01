model FestivalSpeakerPositioning

global {
    geometry shape <- square(100 #m);
    int change_interval <- 500;
    
    // Global metrics for Visualization
    float global_utility_score <- 0.0;
    float base_utility_score <- 0.0; // Utility without crowd optimization

    list<Stage> all_stages;
    
    //Leader agent (global access)
    AgentLeader the_leader;

    init {
        // Create 4 Stages
        create Stage number: 1 { location <- {0, 0}; name <- "Stage A"; my_color <- #red; }
        create Stage number: 1 { location <- {100, 0}; name <- "Stage B"; my_color <- #blue; }
        create Stage number: 1 { location <- {100, 100}; name <- "Stage C"; my_color <- #green; }
        create Stage number: 1 { location <- {0, 100}; name <- "Stage D"; my_color <- #purple; }

        all_stages <- list(Stage);

        // Create the Leader
        create AgentLeader number: 1 {
            the_leader <- self;
            location <- {50, 50}; // Center of map
        }

        // Create 50 Guests
        create Guest number: 50;
    }
}

species AgentLeader skills: [fipa] {
    // Data storage for the current optimization round
    map<agent, list> guest_data <- []; 
    
    // Internal map to track assignments during optimization
    map<agent, Stage> temp_assignments; 

    reflex receive_guest_preferences when: !empty(informs) {
        loop msg over: informs {

            list content <- msg.contents;
            add content at: agent(msg.sender) to: guest_data;
        }
    }

    // Optimize Global Utility
    reflex optimize_and_assign when: length(guest_data) = 50 {
        write "Leader: Received all 50 messages. Starting optimization...";
        
        // 1. Initial Assignment: Assign everyone to their favorite "Base" stage
        temp_assignments <- [];
        loop g over: guest_data.keys {
            map<Stage, float> evaluations <- guest_data[g][0];
            
            Stage best_s <- nil;
            float max_v <- -9999.0;
            loop s over: evaluations.keys {
                if (evaluations[s] > max_v) {
                    max_v <- evaluations[s];
                    best_s <- s;
                }
            }
            add best_s at: g to: temp_assignments;
        }

        // [LOG 2 & CALCULATION] 特别检测 Guest 42 并计算其 Utility
        // 此时 temp_assignments 已经是基于 "Max Base Utility" 分配的了
        loop g over: guest_data.keys {
            // 假设 agent 的 index 是 42 (或者你可以用 g.name = "guest42")
            if (int(g) = 42) {
                map<Stage, float> evals <- guest_data[g][0];
                float c_pref <- float(guest_data[g][1]);
                Stage assigned_s <- temp_assignments[g]; // 此时这就是Base分最高的Stage
                
                // 计算该Stage当前的总人数
                int current_stage_count <- 0;
                loop check_g over: temp_assignments.keys {
                    if (temp_assignments[check_g] = assigned_s) {
                        current_stage_count <- current_stage_count + 1;
                    }
                }
                
                // 计算公式：Max Base + CrowdPref * (Count / 50)
                float max_base <- evals[assigned_s];
                float normalized_crowd <- current_stage_count / 50.0;
                float specific_utility <- max_base + (c_pref * normalized_crowd);
                
                write "Assignment: " + assigned_s;
                write "Stage Population: " + current_stage_count + "/50";
                write "Calculation: " + max_base with_precision 2 + " (Max Base) + " + c_pref with_precision 2 + " * " + normalized_crowd with_precision 2;
                write "Guest 42 Utility: " + specific_utility with_precision 2;
            }
        }

        // 2. Iterative Improvement (Hill Climbing)
        int iterations <- 0;
//        write "Leader: Starting 200 iterations of Hill Climbing...";
        
        loop times: 500 { 
            agent candidate_guest <- one_of(guest_data.keys);
            Stage current_s <- temp_assignments[candidate_guest];
            Stage new_s <- one_of(all_stages - current_s);
            
            float score_before <- calculate_global_utility();
            
            add new_s at: candidate_guest to: temp_assignments;
            
            float score_after <- calculate_global_utility();
            
            if (score_after <= score_before) {
                 add current_s at: candidate_guest to: temp_assignments;
            }
        }
        
        // Update Global Variable and [LOG 3] Print final utility
        global_utility_score <- calculate_global_utility();
        
        Guest g42 <- guest_data.keys[42];
        if (int(g42) = 42) {
                map<Stage, float> evals <- guest_data[g42][0];
                float c_pref <- float(guest_data[g42][1]);
                Stage assigned_s <- temp_assignments[g42]; // 此时这就是Base分最高的Stage
                
                // 计算该Stage当前的总人数
                int current_stage_count <- 0;
                loop check_g over: temp_assignments.keys {
                    if (temp_assignments[check_g] = assigned_s) {
                        current_stage_count <- current_stage_count + 1;
                    }
                }
                
                // 计算公式：Max Base + CrowdPref * (Count / 50)
                float max_base <- evals[assigned_s];
                float normalized_crowd <- current_stage_count / 50.0;
                float specific_utility <- max_base + (c_pref * normalized_crowd);
                
                write "FINAL Assignment: " + assigned_s;
                write "FINAL Stage Population: " + current_stage_count + "/50";
                write "FINAL Calculation: " + max_base with_precision 2 + " (Max Base) + " + c_pref with_precision 2 + " * " + normalized_crowd with_precision 2;
                write "FINAL Guest 42 Utility: " + specific_utility with_precision 2;
            }
        
        // Calculate Base Utility 
        base_utility_score <- 0.0;
        loop g over: guest_data.keys {
             map<Stage, float> evaluations <- guest_data[g][0];
             float pref <- guest_data[g][1]; 
             Stage assigned <- temp_assignments[g];
             base_utility_score <- base_utility_score + (evaluations[assigned] + pref); 
        }

        // 3. Send Orders
        loop g over: temp_assignments.keys {
            do start_conversation to: [g] protocol: 'fipa-propose' performative: 'propose' contents: [temp_assignments[g]];
        }

        // 4. Clear data
        guest_data <- [];
        temp_assignments <- [];
//        write "Leader: Assignments sent. Cycle complete.";
    }

    float calculate_global_utility {
        float total_u <- 0.0;
        
        map<Stage, int> counts <- [];
        loop s over: all_stages { counts[s] <- 0; }
        loop g over: temp_assignments.keys {
            counts[temp_assignments[g]] <- counts[temp_assignments[g]] + 1;
        }
        
        loop g over: temp_assignments.keys {
            map<Stage, float> evaluations <- guest_data[g][0]; 
            float c_pref <- float(guest_data[g][1]); 
            Stage s <- temp_assignments[g];
            
            float base <- evaluations[s];
            float norm_crowd <- counts[s] / 50.0;
            
            float u <- base + (c_pref * norm_crowd);
            total_u <- total_u + u;
        }
        return total_u;
    }
    
    aspect default {
        draw circle(3) color: #black;
        draw "LEADER" color: #black at: location + {0, -5};
    }
}
species Stage skills: [fipa] {
    float lighting_q;
    float sound_q;
    float visual_q;
    float music_q;
    rgb my_color;

    init { do randomize_attributes; }

    reflex update_attributes when: (cycle > 0) and (cycle mod change_interval = 0) {
        do randomize_attributes;
    }

    action randomize_attributes {
        lighting_q <- rnd(0.0, 1.0);
        sound_q <- rnd(0.0, 1.0);
        visual_q <- rnd(0.0, 1.0);
        music_q <- rnd(0.0, 1.0);
    }

    reflex reply_to_guests {
        loop req over: requests {
            map<string, float> specs <- [
                "light"::lighting_q,
                "sound"::sound_q,
                "visual"::visual_q,
                "music"::music_q
            ];
            do inform message: req contents: [specs];
        }
    }

    aspect default {
        draw square(5) color: my_color;
        draw name color: #black size: 3 at: location + {0, -4};
    }
}

species Guest skills: [moving, fipa] {
    float w_light <- rnd(0.0, 1.0);
    float w_sound <- rnd(0.0, 1.0);
    float w_visual <- rnd(0.0, 1.0);
    float w_music <- rnd(0.0, 1.0);

    // -1.0 (Hates crowds) to 1.0 (Loves crowds)
    float crowd_preference <- rnd(-1.0, 1.0);

    Stage target_stage <- nil;
    map<Stage, float> stage_evaluations;
    bool waiting_for_specs <- false;

    // Step 1: Trigger Request
    reflex query_stages when: (cycle = 0) or (cycle mod change_interval = 0) {
        target_stage <- nil;
        stage_evaluations <- [];
        waiting_for_specs <- true;
        // Request specs from stages
        do start_conversation to: list(Stage) protocol: 'no-protocol' performative: 'request' contents: ['get_specs'];
    }

    // Step 2: Receive Stage Specs & Calculate BASE Utility
    reflex collect_replies when: !empty(informs) and waiting_for_specs {
        loop msg over: informs {
            // Only process messages from Stages (ignore Leader logic here if mixed)
            if (msg.sender is Stage) {
                list repContents <- msg.contents;
                map<string, float> specs <- map(repContents[0]);

                float utility <- (specs["light"] * w_light) +
                                 (specs["sound"] * w_sound) +
                                 (specs["visual"] * w_visual) +
                                 (specs["music"] * w_music);

                add utility at: (agent(msg.sender)) to: stage_evaluations;
            }
        }

        // --- CHALLENGE 1: Report to Leader ---
        // Once we have evaluated all 4 stages, send data to Leader instead of moving
        if (length(stage_evaluations) = length(all_stages)) {
            waiting_for_specs <- false; // Done listening to stages
            if (int(self) = 42) {
                write "--------------------------------------------------";
                write " Guest 42 Analysis | Cycle: " + cycle;
                write "   > Stage Evaluations:";
                Stage maxStage;
                float maxscore <- 0.0;
                loop s over: stage_evaluations.keys {
                    float score <- stage_evaluations[s];
                   	if (score > maxscore){
                   		maxscore <- score;
                   		maxStage <- s;
                   	}
                    write "     - " + s + ": " + (score with_precision 2);
                }
                write "GUEST DECISION: " + maxStage;
            }
            // Send map of scores AND crowd preference to the Leader
            do start_conversation to: [the_leader] 
                                  protocol: 'no-protocol' 
                                  performative: 'inform' 
                                  contents: [stage_evaluations, crowd_preference];
        }
    }

    // --- CHALLENGE 1: Listen for Leader Assignment ---
    reflex receive_orders when: !empty(proposes) {
        loop msg over: proposes {
            // The Leader sends the assigned Stage object as the first content item
            list msgcontent <- msg.contents;
            target_stage <- Stage(msgcontent[0]);
            if (int(self) = 42) {
                write "--------------------------------------------------";
            }
        }
    }

    reflex move_to_target when: target_stage != nil {
        if (location distance_to target_stage.location > 10.0) {
            do goto target: target_stage speed: 2.0;
        }
    }

    aspect default {
        // Visualize crowd preference in border color (cyan = hates crowds, yellow = loves crowds)
        rgb border_col <- (crowd_preference < 0) ? #cyan : #yellow;
        draw circle(1) color: (target_stage != nil) ? target_stage.my_color : #gray border: border_col;
    }
}

experiment FestivalSimulation type: gui {
    output {
        display map {
            species Stage;
            species AgentLeader;
            species Guest;
        }

        display "Utility Analysis" {
            chart "Global Utility vs Base"  {
                data "Global Optimized Utility" value: global_utility_score color: #black thickness: 2;
                data "Base Utility (Raw)" value: base_utility_score color: #gray thickness: 2;
            }
        }
    }
}