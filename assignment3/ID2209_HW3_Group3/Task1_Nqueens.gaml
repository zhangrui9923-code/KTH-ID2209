model n_queens

global {
    int board_size <- 4;
    int solutions_found <- 0;
    int max_solutions <- 2;
    
    init {

    // 1) 逐个创建皇后，显式用 i 作为 queen_id / row
    loop i from: 0 to: board_size - 1 {
        create queen_agent {
            queen_id <- i;
            row <- i;
            n <- board_size;
        }
    }
    
    // 2) 把所有 queen 取成一个 list
    list<queen_agent> all_queens <- list(queen_agent);
    
    // 3) 设置 predecessor / successor
    loop i from: 0 to: length(all_queens) - 1 {
        queen_agent current <- all_queens[i];
        if i > 0 {
            current.predecessor <- all_queens[i-1];
        }
        if i < length(all_queens) - 1 {
            current.successor <- all_queens[i+1];
        }
    }
    
    // 4) 让第一个皇后开始
    queen_agent first <- all_queens[0];
    first.has_message <- true;
    first.msg_type <- "START";
    first.msg_data <- [];
}

}

species queen_agent {
    int queen_id;
    int row;
    int n;
    int position <- -1;
    list<int> tried_positions <- [];
    queen_agent predecessor <- nil;
    queen_agent successor <- nil;
    bool is_placed <- false;
    
    bool has_message <- false;
    string msg_type <- "";
    list<int> msg_data <- [];
    
    bool is_safe(int col, list<int> occupied) {
        int idx <- 0;
        loop other_col over: occupied {
            if other_col = col {
                return false;
            }
            if abs(idx - queen_id) = abs(other_col - col) {
                return false;
            }
            idx <- idx + 1;
        }
        return true;
    }
    
    int find_next_position(list<int> occupied) {
        loop col from: 0 to: n - 1 {
            if !(col in tried_positions) and is_safe(col, occupied) {
                return col;
            }
        }
        return -1;
    }
    
    reflex process_message when: has_message {
        has_message <- false;
        
        if msg_type = "START" or msg_type = "POSITION_REQUEST" {
            list<int> occupied <- copy(msg_data);
            int next_pos <- find_next_position(occupied);
            
            if next_pos >= 0 {
                position <- next_pos;
                is_placed <- true;
                tried_positions <- tried_positions + next_pos;
                
                write "Queen " + queen_id + " placed at column " + next_pos;
                
                if successor != nil {
                    list<int> new_occupied <- copy(occupied) + next_pos;
                    successor.has_message <- true;
                    successor.msg_type <- "POSITION_REQUEST";
                    successor.msg_data <- copy(new_occupied);
                } else {
                    solutions_found <- solutions_found + 1;
                    write "\n=== SOLUTION " + solutions_found + " ===";
                    
                    list<queen_agent> all_q <- list(queen_agent);
                    loop q over: all_q {
                        write "Queen " + q.queen_id + " at column " + q.position;
                    }
                    
                    loop r from: 0 to: n - 1 {
                        string row_str <- "";
                        loop c from: 0 to: n - 1 {
                            bool found <- false;
                            loop q over: all_q {
                                if q.row = r and q.position = c {
                                    found <- true;
                                }
                            }
                            row_str <- row_str + (found ? "Q " : ". ");
                        }
                        write row_str;
                    }
                    write "";
                    
                    if solutions_found < max_solutions {
                        write "Finding solution " + (solutions_found + 1) + "...\n";
                        has_message <- true;
                        msg_type <- "BACKTRACK";
                        msg_data <- [];
                    } else {
                        write "=== COMPLETE: " + solutions_found + " SOLUTIONS ===";
                    }
                }
            } else {
                write "Queen " + queen_id + " backtracking";
                if predecessor != nil {
                    predecessor.has_message <- true;
                    predecessor.msg_type <- "BACKTRACK";
                    predecessor.msg_data <- [];
                }
            }
        }
        else if msg_type = "BACKTRACK" {
            if successor != nil {
                successor.has_message <- true;
                successor.msg_type <- "RESET";
                successor.msg_data <- [];
            }
            
            list<int> occupied <- [];
            queen_agent temp <- predecessor;
            loop while: temp != nil {
                occupied <- [temp.position] + occupied;
                temp <- temp.predecessor;
            }
            
            int next_pos <- find_next_position(occupied);
            
            if next_pos >= 0 {
                position <- next_pos;
                is_placed <- true;
                tried_positions <- tried_positions + next_pos;
                
                write "Queen " + queen_id + " placed at column " + next_pos;
                
                if successor != nil {
                    list<int> new_occupied <- copy(occupied) + next_pos;
                    successor.has_message <- true;
                    successor.msg_type <- "POSITION_REQUEST";
                    successor.msg_data <- copy(new_occupied);
                } else {
                    solutions_found <- solutions_found + 1;
                    write "\n=== SOLUTION " + solutions_found + " ===";
                    
                    list<queen_agent> all_q <- list(queen_agent);
                    loop q over: all_q {
                        write "Queen " + q.queen_id + " at column " + q.position;
                    }
                    
                    loop r from: 0 to: n - 1 {
                        string row_str <- "";
                        loop c from: 0 to: n - 1 {
                            bool found <- false;
                            loop q over: all_q {
                                if q.row = r and q.position = c {
                                    found <- true;
                                }
                            }
                            row_str <- row_str + (found ? "Q " : ". ");
                        }
                        write row_str;
                    }
                    write "";
                    
                    if solutions_found < max_solutions {
                        write "Finding solution " + (solutions_found + 1) + "...\n";
                        has_message <- true;
                        msg_type <- "BACKTRACK";
                        msg_data <- [];
                    } else {
                        write "=== COMPLETE: " + solutions_found + " SOLUTIONS ===";
                    }
                }
            } else {
                position <- -1;
                is_placed <- false;
                tried_positions <- [];
                if predecessor != nil {
                    predecessor.has_message <- true;
                    predecessor.msg_type <- "BACKTRACK";
                    predecessor.msg_data <- [];
                }
            }
        }
        else if msg_type = "RESET" {
            position <- -1;
            is_placed <- false;
            tried_positions <- [];
            if successor != nil {
                successor.has_message <- true;
                successor.msg_type <- "RESET";
                successor.msg_data <- [];
            }
        }
    }
    
    aspect default {
        if is_placed {
            draw circle(1) color: #red at: {position * 2, row * 2};
            draw circle(0.8) color: #white at: {position * 2, row * 2};
        }
    }
}

experiment n_queens_experiment type: gui {
    parameter "Board Size" var: board_size min: 4 max: 20;
    parameter "Max Solutions" var: max_solutions min: 1 max: 5;
    
    output {
        display main_display {
            graphics "board" {
                loop i from: 0 to: board_size - 1 {
                    loop j from: 0 to: board_size - 1 {
                        rgb cell_color <- (mod(i + j, 2) = 0) ? #lightgray : #white;
                        draw square(1.8) at: {i * 2, j * 2} color: cell_color border: #black;
                    }
                }
            }
            species queen_agent aspect: default;
        }
        
        monitor "Solutions" value: solutions_found;
        monitor "Target" value: max_solutions;
    }
}
