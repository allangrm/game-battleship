# frozen_string_literal: true

# Controla as cargas de armas de um participante. O ataque básico é ilimitado;
# cada participante recebe uma instância própria com os mesmos limites do mapa.
# 
# @author Júlio Pedro
# @version 1.2
class WeaponInventory
  class WeaponUnavailableError < StandardError; end

  WEAPONS = %i[basic_shot missile airplane].freeze
  UNLIMITED = nil

  LOADOUTS = {
    poca: { missile: 1, airplane: 1 }.freeze,
    lago: { missile: 2, airplane: 1 }.freeze,
    oceano: { missile: 3, airplane: 1 }.freeze
  }.freeze

  attr_reader :map_type

  def self.for_map(map_type)
    normalized_map_type = map_type.to_s.strip.to_sym
    limits = LOADOUTS[normalized_map_type]
    raise ArgumentError, "Mapa inválido para o inventário: #{map_type.inspect}" unless limits

    new(limits, map_type: normalized_map_type)
  end

  def initialize(charges = {}, map_type: nil)
    normalized_charges = normalize_charges(charges)
    @map_type = map_type
    @remaining = WEAPONS.to_h do |weapon|
      [weapon, weapon == :basic_shot ? UNLIMITED : normalized_charges.fetch(weapon, 0)]
    end
  end

  def available?(weapon)
    uses = remaining(weapon)
    uses.nil? || uses.positive?
  end

  def remaining(weapon)
    @remaining.fetch(identifier_for(weapon))
  end

  # Retorna a quantidade restante; nil representa uma arma ilimitada.
  def consume!(weapon)
    identifier = identifier_for(weapon)
    return UNLIMITED if @remaining[identifier].nil?

    unless @remaining[identifier].positive?
      raise WeaponUnavailableError, "A arma #{identifier} não possui cargas restantes"
    end

    @remaining[identifier] -= 1
  end

  def to_h
    @remaining.dup.freeze
  end

  private

  def normalize_charges(charges)
    unless charges.respond_to?(:each_pair)
      raise ArgumentError, "charges precisa ser um Hash"
    end

    charges.each_pair.to_h do |weapon, amount|
      identifier = identifier_for(weapon)
      if identifier == :basic_shot
        raise ArgumentError, "O ataque básico é sempre ilimitado"
      end
      unless amount.is_a?(Integer) && amount >= 0
        raise ArgumentError, "A quantidade de #{identifier} deve ser um inteiro não negativo"
      end

      [identifier, amount]
    end
  end

  def identifier_for(weapon)
    raw_identifier = weapon.respond_to?(:identifier) ? weapon.identifier : weapon
    identifier = raw_identifier.to_s.strip.to_sym
    return identifier if WEAPONS.include?(identifier)

    raise ArgumentError, "Arma inválida: #{raw_identifier.inspect}"
  end
end
