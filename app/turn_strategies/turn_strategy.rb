# frozen_string_literal: true

# Contrato das estratégias que decidem se o atacante permanece com o turno.
class TurnStrategy
  def keep_turn?(_attack_results)
    raise NotImplementedError, "#{self.class} precisa implementar #keep_turn?"
  end
end
