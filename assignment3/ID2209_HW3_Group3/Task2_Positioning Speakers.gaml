model FestivalSpeakerPositioning

global {
    // 1. Global Setup
    geometry shape <- square(100 #m);
    int change_interval <- 500;
    
    // List of stages for guests to check count against
    list<Stage> all_stages;

    init {
        // Create 4 Stages at corners
        create Stage number: 1 { location <- {0, 0}; name <- "Stage A"; my_color <- #red; }
        create Stage number: 1 { location <- {100, 0}; name <- "Stage B"; my_color <- #blue; }
        create Stage number: 1 { location <- {100, 100}; name <- "Stage C"; my_color <- #green; }
        create Stage number: 1 { location <- {0, 100}; name <- "Stage D"; my_color <- #purple; }
        
        // Store reference for guests
        all_stages <- list(Stage);

        // Create 50 Guests
        create Guest number: 50;
    }
}

species Stage skills: [fipa] {
    // 2. Species: Stage
    float lighting_q;
    float sound_q;
    float visual_q;
    float music_q;
    rgb my_color;

    init {
        do randomize_attributes;
    }

    // Dynamic Reflex: Randomize attributes periodically
    reflex update_attributes when: (cycle > 0) and (cycle mod change_interval = 0) {
        do randomize_attributes;
        write name + ": Attributes shuffled!";
    }

    action randomize_attributes {
        lighting_q <- rnd(0.0, 1.0);
        sound_q <- rnd(0.0, 1.0);
        visual_q <- rnd(0.0, 1.0);
        music_q <- rnd(0.0, 1.0);
    }

    // Communication: Reply to guests
    reflex reply_to_guests {
        // Constraint: Loop over requests
        loop req over: requests {
            // Prepare data map
            map<string, float> specs <- [
                "light"::lighting_q, 
                "sound"::sound_q, 
                "visual"::visual_q, 
                "music"::music_q
            ];
            
            // Reply using 'inform'. GAML wraps 'contents' in a list automatically.
            do inform message: req contents: [specs];
        }
    }
    
    aspect default {
        draw square(5) color: my_color;
        draw name color: #black size: 3 at: location + {0, -4};
    }
}

species Guest skills: [moving, fipa] {
    // 3. Species: Guest
    
    // Preferences (Weights)
    float w_light <- rnd(0.0, 1.0);
    float w_sound <- rnd(0.0, 1.0);
    float w_visual <- rnd(0.0, 1.0);
    float w_music <- rnd(0.0, 1.0);

    Stage target_stage <- nil;
    
    // Temporary memory to store utilities from stages before deciding
    map<Stage, float> stage_evaluations; 
    bool waiting_for_decision <- false;

    // Step 1: Trigger Request
    reflex query_stages when: (cycle = 0) or (cycle mod change_interval = 0) {
        // Reset state
        target_stage <- nil;
        stage_evaluations <- []; 
        waiting_for_decision <- true;
        
        // Send request to ALL stages
        do start_conversation to: list(Stage) protocol: 'no-protocol' performative: 'request' contents: ['get_specs'];
    }

    // Step 2: Receive & Parse
    reflex collect_replies when: !empty(informs) and waiting_for_decision {
        
        // Constraint: Loop over informs
        loop msg over: informs {
            
            // --- Constraint: Exact Parsing Logic ---
            // 1. Extract content as list
            list repContents <- msg.contents;
            // 2. Cast first element to map
            map<string, float> specs <- map(repContents[0]);
            
            // Calculate Utility
            float utility <- (specs["light"] * w_light) + 
                             (specs["sound"] * w_sound) + 
                             (specs["visual"] * w_visual) + 
                             (specs["music"] * w_music);
                             
            // Store result mapping the sender (Stage agent) to the score
            add utility at: (agent(msg.sender)) to: stage_evaluations;
        }

        // Step 4: Validation (Synchronization)
        // Check if we have received replies from ALL stages
        if (length(stage_evaluations) = length(all_stages)) {
        	if (int(self) = 42) {
                write "--------------------------------------------------";
                write " Guest 42 Analysis | Cycle: " + cycle;
                
                write "   > My Weights: " 
                      + "Light=" + (w_light with_precision 2) + " | " 
                      + "Sound=" + (w_sound with_precision 2) + " | " 
                      + "Visual=" + (w_visual with_precision 2) + " | " 
                      + "Music=" + (w_music with_precision 2);

                write "   > Stage Evaluations:";
                loop s over: stage_evaluations.keys {
                    float score <- stage_evaluations[s];
                    write "     - " + s + ": " + (score with_precision 2);
                }
            }
            do make_decision;
            if (int(self) = 42) {
                write " FINAL DECISION: " + target_stage;
                
                if (target_stage != nil) {
                     write "   > Winning Score: " + (stage_evaluations[target_stage] with_precision 2);
                }
                write "--------------------------------------------------";
            }
        }
    }

    // Step 5: Action
    action make_decision {
        // Find the stage with the highest utility score
        float max_score <- -1.0;
        Stage best_stage <- nil;
        
        loop s over: stage_evaluations.keys {
            if (stage_evaluations[s] > max_score) {
                max_score <- stage_evaluations[s];
                best_stage <- s;
            }
        }
        
        target_stage <- best_stage;
        waiting_for_decision <- false; // Stop listening until next interval
    }

    // Movement Logic
    reflex move_to_target when: target_stage != nil {
        if (location distance_to target_stage.location > 10.0) {
            do goto target: target_stage speed: 2.0;
        }
    }

    aspect default {
        draw circle(1) color: (target_stage != nil) ? target_stage.my_color : #gray border: #black;
    }
}

experiment FestivalSimulation type: gui {
    output {
        display map {
            species Stage;
            species Guest;
        }

        // 4. Visualization: Series Chart
        display "Audience Distribution" {
            chart "Guests per Stage" type: series  {
                data "Stage A" value: Guest count (each.target_stage != nil and each.target_stage.name = "Stage A") color: #red;
                data "Stage B" value: Guest count (each.target_stage != nil and each.target_stage.name = "Stage B") color: #blue;
                data "Stage C" value: Guest count (each.target_stage != nil and each.target_stage.name = "Stage C") color: #green;
                data "Stage D" value: Guest count (each.target_stage != nil and each.target_stage.name = "Stage D") color: #purple;
            }
        }
    }
}