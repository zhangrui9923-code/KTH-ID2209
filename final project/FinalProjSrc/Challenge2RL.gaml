model FestivalSimulation

global {
   
    // Number of agents
    int num_guests <- 50;
    int num_bars <- 3;
    int num_stages <- 2;
    
    // FIPA toggle 
    bool use_fipa <- true;
    
    // Simulation parameters
    float interaction_distance <- 5.0;
    
    // Environment size
    float env_size <- 100.0;
    geometry shape <- square(env_size);
    
    // Q-LEARNING HYPERPARAMETERS
    float alpha <- 0.1;      // Learning Rate
    float gamma <- 0.9;      // Discount Factor
    float epsilon <- 0.15;   // Exploration Rate
    
    // Statistics
    float global_avg_happiness <- 0.5;
    int total_positive_interactions <- 0;
    int total_negative_interactions <- 0;
    int total_fipa_messages_sent <- 0;
    
    // Guest Types
    list<string> type_names <- ["Elderly", "Child", "Student", "Office Worker", "Couple"];
    list<rgb> type_colors <- [#gray, #yellow, #blue, #brown, #pink];
    
    // ========================================================================
    // INITIALIZATION
    // ========================================================================
    
    init {
        write "============================================";
        write "FESTIVAL SIMULATION (Q-LEARNING FULL)";
        write "============================================";
        
        // 1. Create Bars
        list<point> bar_locations <- [{40.0, 80.0}, {20.0, 50.0}, {60.0, 60.0}];
        loop i from: 0 to: length(bar_locations) - 1 {
            create Bar {
                location <- bar_locations[i]; 
                bar_name <- "Bar_" + string(i); 
                quality <- rnd(0.3, 0.9);
            }
        }

        // 2. Create Stages
        list<point> stage_locations <- [{80.0, 20.0}, {50.0, 10.0}];
        loop j from: 0 to: length(stage_locations) - 1 {
            create Stage {
                location <- stage_locations[j];
                stage_name <- "Stage_" + string(j);
                performance_quality <- rnd(0.4, 1.0);
            }
        }
        
        // 3. Create Guests
        create Guest number: num_guests {
            location <- {rnd(env_size), rnd(env_size)};
            my_id <- int(self); // Store ID for tracking Agent 42
            
            // Assign type
            guest_type <- rnd(1, 5);
            
            // Initialize personality traits
            if (guest_type = 1) { // Elderly
                sociability <- rnd(0.3, 0.5); risk_aversion <- rnd(0.7, 0.95); trust <- rnd(0.6, 0.85);
            } else if (guest_type = 2) { // Child
                sociability <- rnd(0.7, 1.0); risk_aversion <- rnd(0.05, 0.3); trust <- rnd(0.7, 0.95);
            } else if (guest_type = 3) { // Student
                sociability <- rnd(0.6, 0.9); risk_aversion <- rnd(0.2, 0.5); trust <- rnd(0.5, 0.8);
            } else if (guest_type = 4) { // Office Worker
                sociability <- rnd(0.4, 0.7); risk_aversion <- rnd(0.5, 0.8); trust <- rnd(0.3, 0.6);
            } else { // Couple
                sociability <- rnd(0.3, 0.6); risk_aversion <- rnd(0.4, 0.7); trust <- rnd(0.5, 0.8);
            }
            
            // Initialize Q-Tables
            // 1. Venue Q-Table: Key = Venue Name, Value = Q-Score
            loop b over: Bar { q_venue[b.bar_name] <- 0.5; }
            loop s over: Stage { q_venue[s.stage_name] <- 0.5; }
            
            // 2. Interaction Q-Table: Key = "TargetType_Action", Value = Q-Score
            // Actions: "Socialize"
            // Target Types: "1", "2", "3", "4", "5"
            loop i from: 1 to: 5 {
                q_interaction[string(i) + "_Socialize"] <- 0.0;
            }
        }
    }
    
    reflex update_metrics {
        if (length(Guest) > 0) {
            global_avg_happiness <- mean(Guest collect each.happiness);
        }
    }
}

// ============================================================================
// ENV SPECIES
// ============================================================================

species Bar {
    string bar_name;
    float quality;
    int visitors_today <- 0;
    
    aspect default {
        draw square(6) color: #brown border: #black;
        draw bar_name color: #white font: font("Arial", 10, #bold) at: location + {0, -4};
    }
}

species Stage {
    string stage_name;
    float performance_quality;
    int audience_count <- 0;
    
    reflex change_performance when: (cycle mod 200) = 0 {
        performance_quality <- rnd(0.3, 1.0);
    }
    
    aspect default {
        draw triangle(8) color: #purple border: #black;
        draw stage_name color: #white font: font("Arial", 10, #bold) at: location + {0, -5};
    }
}

// ============================================================================
// AGENT: GUEST (With Q-Learning & FIPA)
// ============================================================================

species Guest skills: [moving, fipa] {
    
    // ID for tracking
    int my_id;
    
    // Attributes
    int guest_type;
    float sociability;
    float risk_aversion;
    float trust;
    float happiness <- 0.5;
    
    // Q-Learning Memory
    map<string, float> q_venue;       // Stores Q-values for locations
    map<string, float> q_interaction; // Stores Q-values for social actions
    
    // State Tracking
    string current_state <- "wandering";
    point target_location;
    Bar current_bar;
    Stage current_stage;
    string last_venue_action; // Name of venue chosen
    int time_at_venue <- 0;
    
    // Cooldowns
    map<Guest, int> last_interaction_cycle;
    int fipa_cooldown <- 0;

    // ========================================================================
    // MAIN LOOP
    // ========================================================================
    reflex live {
        if (fipa_cooldown > 0) { fipa_cooldown <- fipa_cooldown - 1; }
        
        // Happiness Decay
        float decay_rate <- 0.005; 
    	if (guest_type = 2 or guest_type = 3) { decay_rate <- 0.010; }
    	happiness <- happiness - decay_rate;
        
        // State Machine
        if (current_state = "wandering") {
            do wander_behavior;
        } else if (current_state = "going_to_venue") {
            do move_to_target;
        } else if (current_state = "at_venue") {
            do venue_behavior;
        }
        
        // Happiness Clamping
        if (happiness < 0.0) { happiness <- 0.0; }
        if (happiness > 1.0) { happiness <- 1.0; }
    }



    // ========================================================================
    // BEHAVIOR: WANDERING & INTERACTION
    // ========================================================================
    action wander_behavior {
        float my_speed <- 1.0 + sociability;
        if (guest_type = 1) { my_speed <- 0.6; }
        if (guest_type = 2) { my_speed <- 1.8; }
        
        do wander amplitude: 30.0 speed: my_speed;
        
        // Q-Learning Choice: Go to Venue?
        // Probability based on sociability, but choice based on Q-Table
        if (flip(0.02 + sociability * 0.03)) {
            do choose_venue_ql;
        }
        
        // Q-Learning Choice: Interact?
        do check_social_interactions_ql;
    }
    
    // ========================================================================
    // Q-LEARNING: VENUE SELECTION
    // ========================================================================
    action choose_venue_ql {
        // Epsilon-Greedy
        string chosen_action <- nil;
        list<string> venues <- q_venue.keys;
        bool isexplore <- true;
        
        if (flip(epsilon)) {
            chosen_action <- venues at rnd(length(venues) - 1); // Explore
        } else {
            // Exploit
            isexplore <- false;
            float max_q <- -9999.0;
            loop v over: venues {
                if (q_venue[v] > max_q) {
                    max_q <- q_venue[v];
                    chosen_action <- v;
                }
            }
        }
        
        last_venue_action <- chosen_action;
        
        // Identify Target
        Bar b_target <- Bar first_with (each.bar_name = chosen_action);
        Stage s_target <- Stage first_with (each.stage_name = chosen_action);
        
        if (b_target != nil) {
            target_location <- b_target.location;
            current_bar <- b_target;
            current_stage <- nil;
            current_state <- "going_to_venue";
        } else if (s_target != nil) {
            target_location <- s_target.location;
            current_stage <- s_target;
            current_bar <- nil;
            current_state <- "going_to_venue";
        }
        
        if (my_id = 42) { 
        	write "Decided Venue: " + chosen_action;
        	if(isexplore){
        		write "Mode: Explore";
        	}else{
        		write "Mode: Exploit";
        	}
        	// When going to a venue
		    write "Guest 42 (" + type_names[guest_type - 1] + ")";
		    write "Current Happiness: " + string(happiness);
		    write "Current State: " + current_state;
		    write "Target Venue: " + last_venue_action;
		    write "All Venue Q-Values:";
		    loop v over: q_venue.keys {
		        write "  Venue " + v + ": " + (q_venue[v] with_precision 4);
		    } 
		    write "--------------------------------------------------";
        }
    }
    
    action move_to_target {
        if (target_location != nil) {
            do goto target: target_location speed: 1.5;
            if (self distance_to target_location < 3.0) {
                current_state <- "at_venue";
                time_at_venue <- 0;
            }
        }
    }
    
    // ========================================================================
    // BEHAVIOR: AT VENUE & REWARD
    // ========================================================================
    action venue_behavior {
        time_at_venue <- time_at_venue + 1;
        float reward <- 0.0;
        
        // CALCULATE REWARD (Original Logic)
        if (current_bar != nil) {
            float experience <- current_bar.quality + rnd(-0.1, 0.1);
            if (guest_type = 1) { experience <- experience * 0.7; }
            if (guest_type = 4) { experience <- experience * 1.2; }
            
            reward <- (experience - 0.5) * 0.02; 
            
            // FIPA: Share experience (Legacy logic)
            if (use_fipa and fipa_cooldown = 0 and time_at_venue = 10) {
                do send_fipa_message(current_bar.bar_name, experience);
            }
            
        } else if (current_stage != nil) {
            float experience <- current_stage.performance_quality + rnd(-0.1, 0.1);
            if (guest_type = 2) { experience <- experience * 1.3; }
            if (guest_type = 5) { experience <- experience * 1.2; }
            
            reward <- (experience - 0.5) * 0.015;
        }
        
        // APPLY REWARD
        happiness <- happiness + reward;
        
        // UPDATE Q-TABLE (Venue)
        // Since leaving is terminal for the venue episode, Q_next is approx 0 (wandering)
        float current_q <- q_venue[last_venue_action];
        q_venue[last_venue_action] <- current_q + alpha * (reward - current_q);
        
        // Socialize while at venue
        do check_social_interactions_ql;
        
        // Leave Logic
        int stay_duration <- 30 + int(sociability * 40);
        if (time_at_venue > stay_duration or flip(0.01)) {
            current_state <- "wandering";
            current_bar <- nil;
            current_stage <- nil;
        }
    }
    
    // ========================================================================
    // Q-LEARNING: SOCIAL INTERACTIONS
    // ========================================================================
    action check_social_interactions_ql {
        list<Guest> nearby <- (Guest at_distance interaction_distance) where (each != self);
        
        loop other over: nearby {
            // Check Cooldown
            bool can_interact <- true;
            if (last_interaction_cycle contains_key other) {
                if (cycle - last_interaction_cycle[other] < 20) { can_interact <- false; }
            }
            
            if (can_interact) {
                // 1. OBSERVE STATE: Target's Type
                string state_key <- string(other.guest_type);
                
                // 2. CHOOSE ACTION: Socialize or Ignore
                string action_key <- "Ignore";
                
                // Epsilon-Greedy
                if (flip(epsilon)) {
                    if (flip(0.5)) { action_key <- "Socialize"; }
                } else {
                    float q_social <- q_interaction[state_key + "_Socialize"];
                    float q_ignore <- q_interaction[state_key + "_Ignore"];
                    if (q_social > q_ignore) { action_key <- "Socialize"; }
                }
                
                float reward <- 0.0;
                
                // 3. EXECUTE & GET REWARD
                if (action_key = "Socialize") {
                    // **CRITICAL**: Use the exact complex logic to determine outcome
                    float happiness_delta <- get_interaction_result(other);
                    
                    // Update My Happiness
                    happiness <- happiness + happiness_delta;
                    reward <- happiness_delta;
                    
                    // Mark cooldown
                    last_interaction_cycle[other] <- cycle;
                    
                } else {
                    // Ignore Action
                    reward <- 0.0; // Neutral
                }
                
                // 4. UPDATE Q-TABLE
                string full_key <- state_key + "_" + action_key;
                float old_q <- q_interaction[full_key];
                q_interaction[full_key] <- old_q + alpha * (reward - old_q);
                
                if (action_key = "Socialize" and my_id = 42){
                	write "Socialized with Type " + state_key + ". Reward: " + reward;
                	// When interacting with an agent
				    write "Guest 42 (" + type_names[guest_type - 1] + ")";
				    write "Current Happiness: " + string(happiness);
				    write "Current State: " + current_state;
				    write "Top Interaction Q-Values:";
				    loop i from: 1 to: 5 {
				        string t <- string(i);
				        write "  vs Type " + t + ": Soc=" + (q_interaction[t+"_Socialize"] with_precision 5);
				    }
				    write "--------------------------------------------------";
                }
            }
        }
    }
    
    // ========================================================================
    // COMPLEX LOGIC (PRESERVED)
    // Returns the happiness delta for SELF based on original probability trees
    // ========================================================================
    float get_interaction_result(Guest other) {
        string interaction_type <- "neutral";
        
        // --- LOGIC TREE START ---
        if (guest_type = 1) { // Elderly
            if (other.guest_type = 1) { interaction_type <- "positive"; }
            else if (other.guest_type = 2) { if (flip(0.6)) { interaction_type <- "positive"; } else { interaction_type <- "negative"; } }
            else if (other.guest_type = 3) { if (flip(0.4)) { interaction_type <- "positive"; } else { interaction_type <- "neutral"; } }
            else if (other.guest_type = 4) { interaction_type <- "neutral"; }
            else if (other.guest_type = 5) { interaction_type <- "positive"; }
        } else if (guest_type = 2) { // Child
            if (other.guest_type = 1) { if (flip(0.7)) { interaction_type <- "positive"; } else { interaction_type <- "negative"; } }
            else if (other.guest_type = 2) { if (flip(0.8)) { interaction_type <- "positive"; } else { interaction_type <- "conflict"; } }
            else if (other.guest_type = 3) { interaction_type <- "positive"; }
            else if (other.guest_type = 4) { if (flip(0.5)) { interaction_type <- "neutral"; } else { interaction_type <- "negative"; } }
            else if (other.guest_type = 5) { interaction_type <- "neutral"; }
        } else if (guest_type = 3) { // Student
            if (other.guest_type = 1) { if (flip(0.6)) { interaction_type <- "positive"; } else { interaction_type <- "neutral"; } }
            else if (other.guest_type = 2) { interaction_type <- "positive"; }
            else if (other.guest_type = 3) { if (flip(0.85)) { interaction_type <- "positive"; } else { interaction_type <- "conflict"; } }
            else if (other.guest_type = 4) { if (flip(0.5)) { interaction_type <- "positive"; } else { interaction_type <- "neutral"; } }
            else if (other.guest_type = 5) { interaction_type <- "neutral"; }
        } else if (guest_type = 4) { // Worker
            if (other.guest_type = 1) { interaction_type <- "neutral"; }
            else if (other.guest_type = 2) { if (flip(0.4)) { interaction_type <- "positive"; } else { interaction_type <- "negative"; } }
            else if (other.guest_type = 3) { if (flip(0.5)) { interaction_type <- "positive"; } else { interaction_type <- "neutral"; } }
            else if (other.guest_type = 4) { if (flip(0.7)) { interaction_type <- "positive"; } else { interaction_type <- "neutral"; } }
            else if (other.guest_type = 5) { if (flip(0.3)) { interaction_type <- "negative"; } else { interaction_type <- "neutral"; } }
        } else if (guest_type = 5) { // Couple
            if (other.guest_type = 1) { interaction_type <- "positive"; }
            else if (other.guest_type = 2) { if (flip(0.6)) { interaction_type <- "positive"; } else { interaction_type <- "neutral"; } }
            else if (other.guest_type = 3) { interaction_type <- "neutral"; }
            else if (other.guest_type = 4) { interaction_type <- "neutral"; }
            else if (other.guest_type = 5) { if (flip(0.7)) { interaction_type <- "positive"; } else { interaction_type <- "neutral"; } }
        }
        // --- LOGIC TREE END ---
        
        // Risk aversion modifier
        if (interaction_type = "conflict" and flip(risk_aversion)) {
            interaction_type <- "negative";
        }
        
        // Calculate Happiness Delta (Reward)
        float delta <- 0.0;
        
        if (interaction_type = "positive") {
            delta <- 0.03 * (1 + sociability);
            total_positive_interactions <- total_positive_interactions + 1;
            // Also update the other agent's happiness (side effect)
            ask other { happiness <- happiness + (0.03 * (1 + sociability)); }
            
        } else if (interaction_type = "neutral") {
            delta <- rnd(-0.005, 0.01);
            
        } else if (interaction_type = "negative") {
            delta <- -0.02 * (1 - risk_aversion);
            total_negative_interactions <- total_negative_interactions + 1;
            ask other { happiness <- happiness - (0.02 * (1 - risk_aversion)); }
            
        } else if (interaction_type = "conflict") {
            delta <- -0.05 * (1 - risk_aversion);
            total_negative_interactions <- total_negative_interactions + 1;
            ask other { happiness <- happiness - (0.05 * (1 - risk_aversion)); }
        }
        
        return delta;
    }
    
    // ========================================================================
    // FIPA COMMUNICATIONS
    // ========================================================================
    action send_fipa_message(string bar, float exp) {
        list<string> content <- [bar, string(exp)];
        list<Guest> nearby <- (Guest at_distance 10.0) where (each != self);
        
        if (length(nearby) > 0) {
            do start_conversation to: nearby performative: "inform" contents: content;
            total_fipa_messages_sent <- total_fipa_messages_sent + 1;
            fipa_cooldown <- 30;
        }
    }
    
    reflex receive_fipa_messages when: !empty(informs) {
        loop msg over: informs {
            // Processing logic (simplified for this prompt as Q-learning is main focus)
            // But we acknowledge receipt to clear the queue
        }
    }

    // ========================================================================
    // ASPECTS
    // ========================================================================
    aspect detailed {
        rgb my_color <- type_colors[guest_type - 1];
        float intensity <- 0.5 + happiness * 0.5;
        rgb display_color <- rgb(my_color.red * intensity, my_color.green * intensity, my_color.blue * intensity);
        
        draw circle(2.5) color: display_color border: #black;
        draw string(guest_type) color: #black font: font("Arial", 8, #bold) at: location + {0, -3};
        
        // ID 42 Highlight
        if (my_id = 42) {
             draw circle(4.0) border: #red;
             draw "42" color: #red font: font("Arial", 12, #bold) at: location + {0, -6};
        }
        
        // Happiness bar
        draw rectangle(4, 0.8) color: #red at: location + {0, 4};
        draw rectangle(4 * happiness, 0.8) color: #green at: location + {-2 + 2*happiness, 4};
    }
}

// ============================================================================
// EXPERIMENT
// ============================================================================

experiment FestivalSimulation type: gui {
    
    output {
        display "Festival Map" type: java2D {
            species Bar aspect: default;
            species Stage aspect: default;
            species Guest aspect: detailed;
        }
        
        display "Statistics" refresh: every(5#cycles) {
            chart "Happiness" type: series size: {1.0, 1.0} position: {0, 0} {
                data "Global Happiness" value: global_avg_happiness color: #blue;
            }
//            chart "Interactions" type: series size: {1.0, 0.5} position: {0, 0.5} {
//                data "Positive" value: total_positive_interactions color: #green;
//                data "Negative" value: total_negative_interactions color: #red;
//            }
        }
        
        display "Happiness by Type" refresh: every(10#cycles) {
            chart "Average Happiness by Guest Type" type: histogram {
                data "Elderly" value: (Guest where (each.guest_type = 1)) mean_of each.happiness color: #gray;
                data "Child" value: (Guest where (each.guest_type = 2)) mean_of each.happiness color: #yellow;
                data "Student" value: (Guest where (each.guest_type = 3)) mean_of each.happiness color: #blue;
                data "Worker" value: (Guest where (each.guest_type = 4)) mean_of each.happiness color: #brown;
                data "Couple" value: (Guest where (each.guest_type = 5)) mean_of each.happiness color: #pink;
            }
        }
    }
}